import SwiftUI
import PhotosUI
import UIKit

struct PhotoDraft: Identifiable, Equatable {
    let id: UUID
    let image: UIImage
    let existingPieceID: UUID?
    let existingFilename: String?

    init(
        id: UUID = UUID(),
        image: UIImage,
        existingPieceID: UUID? = nil,
        existingFilename: String? = nil
    ) {
        self.id = id
        self.image = image
        self.existingPieceID = existingPieceID
        self.existingFilename = existingFilename
    }

    static func == (lhs: PhotoDraft, rhs: PhotoDraft) -> Bool { lhs.id == rhs.id }
}

enum EditorMode {
    case create
    case edit(Collection)

    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }

    var existingCollection: Collection? {
        if case .edit(let c) = self { return c }
        return nil
    }

    var footerLabel: String {
        isEdit ? "update" : "publish"
    }
}

private struct CardFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private let editorSpace = "editor"
private let deleteColor = Color(hex: "9B1515")

struct CreateEditView: View {
    let mode: EditorMode
    let initialPhotos: [UIImage]
    var onCancel: () -> Void
    var onSave: (_ title: String, _ drafts: [PhotoDraft]) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var drafts: [PhotoDraft] = []
    @State private var title: String = ""
    @State private var showCancelConfirm: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var morePickerItems: [PhotosPickerItem] = []
    @State private var showMorePicker: Bool = false
    @State private var didSave: Bool = false

    // Custom drag state.
    @State private var draggingID: UUID? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var dragTouchOffset: CGSize = .zero
    @State private var didCaptureTouchOffset: Bool = false
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var editorSize: CGSize = .zero
    @State private var isOverDeleteZone: Bool = false

    // Edge-hold-to-reorder state.
    @State private var edgeHoldDirection: Int = 0  // -1 left, 0 none, 1 right
    @State private var edgeHoldTask: Task<Void, Never>? = nil

    // Scroll position binding (iOS 17+) for programmatic auto-scroll.
    @State private var scrollAnchorID: UUID? = nil

    private let footerHeight: CGFloat = 40
    private let footerTopCurve: CGFloat = 48
    private let maxSelection: Int = 10
    private let titlePlaceholder: String = "[untitled collection]"
    private let edgeHoldZone: CGFloat = 70
    private let edgeInitialDelayMs: Int = 200
    private let edgeStepIntervalMs: Int = 500

    private var deleteThresholdY: CGFloat {
        // Bottom 35% of the editor triggers delete — much higher than the
        // visible footer so it's easy to reach.
        editorSize.height * 0.65
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                editorStack

                if showCancelConfirm {
                    confirmPrompt(
                        message: "are you sure?",
                        yesLabel: "yes",
                        noLabel: "no",
                        onYes: {
                            showCancelConfirm = false
                            onCancel()
                        },
                        onNo: { showCancelConfirm = false }
                    )
                    .transition(.opacity)
                    .zIndex(300)
                }

                if showDeleteConfirm {
                    confirmPrompt(
                        message: "delete this collection?",
                        yesLabel: "delete",
                        noLabel: "cancel",
                        onYes: {
                            showDeleteConfirm = false
                            onDelete?()
                        },
                        onNo: { showDeleteConfirm = false }
                    )
                    .transition(.opacity)
                    .zIndex(300)
                }
            }
            .coordinateSpace(name: editorSpace)
            .onAppear { editorSize = geo.size }
            .onChange(of: geo.size) { _, newSize in editorSize = newSize }
        }
        .onAppear { loadInitialState() }
        .photosPicker(
            isPresented: $showMorePicker,
            selection: $morePickerItems,
            maxSelectionCount: max(1, maxSelection - drafts.count),
            selectionBehavior: .ordered,
            matching: .images
        )
        .onChange(of: morePickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadMorePhotos(items) }
        }
    }

    // MARK: - Editor stack

    private var editorStack: some View {
        ZStack {
            HallwaysTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .opacity(draggingID == nil ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: draggingID)
                carousel
            }

            // Ghost card following the finger while dragging — 85% scale,
            // appears immediately on long-press success.
            if let id = draggingID, let draft = drafts.first(where: { $0.id == id }) {
                photoCard(draft: draft)
                    .scaleEffect(0.85)
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                    .position(
                        x: dragLocation.x - dragTouchOffset.width,
                        y: dragLocation.y - dragTouchOffset.height
                    )
                    .allowsHitTesting(false)
                    .zIndex(100)
                    .transition(.identity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            publishFooter
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onPreferenceChange(CardFramesKey.self) { cardFrames = $0 }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                showCancelConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(HallwaysTheme.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            TextField(titlePlaceholder, text: $title)
                .font(.specialElite(size: 18))
                .foregroundColor(HallwaysTheme.text)
                .multilineTextAlignment(.center)
                .submitLabel(.done)

            if mode.isEdit {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(HallwaysTheme.text)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - Carousel

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .center, spacing: 24) {
                ForEach(drafts) { draft in
                    cardSlot(draft: draft)
                }

                if drafts.count < maxSelection {
                    addMoreButton
                        .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .scrollPosition(id: $scrollAnchorID)
        .scrollDisabled(draggingID != nil)
        .frame(maxHeight: .infinity)
        .padding(.bottom, footerTopCurve + 16)
    }

    @ViewBuilder
    private func cardSlot(draft: PhotoDraft) -> some View {
        let isDragged = draggingID == draft.id
        photoCard(draft: draft)
            .opacity(isDragged ? 0 : 1)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: CardFramesKey.self,
                            value: [draft.id: geo.frame(in: .named(editorSpace))]
                        )
                }
            )
            .id(draft.id)
            .simultaneousGesture(longPressDragGesture(for: draft.id))
    }

    // MARK: - Long press + drag gesture

    private func longPressDragGesture(for id: UUID) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before:
                DragGesture(minimumDistance: 0, coordinateSpace: .named(editorSpace))
            )
            .onChanged { value in
                switch value {
                case .first(true):
                    beginLiftIfNeeded(for: id)
                case .second(_, let drag):
                    beginLiftIfNeeded(for: id)
                    if let drag = drag {
                        handleDragChanged(drag, for: id)
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                if case .second(_, let drag?) = value {
                    handleDragEnded(at: drag.location, for: id)
                } else {
                    cancelDrag()
                }
            }
    }

    // Lifts the card to ghost state. Happens the moment the long press
    // succeeds — before any movement — so users see immediate feedback.
    private func beginLiftIfNeeded(for id: UUID) {
        guard draggingID == nil else { return }
        let center = cardFrames[id].map { CGPoint(x: $0.midX, y: $0.midY) } ?? .zero
        dragLocation = center
        dragTouchOffset = .zero
        didCaptureTouchOffset = false
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            draggingID = id
        }
    }

    private func handleDragChanged(_ drag: DragGesture.Value, for id: UUID) {
        // On the first drag value, compute the offset between the actual
        // finger position and the card center so the ghost stays "anchored"
        // where the user grabbed it.
        if !didCaptureTouchOffset {
            if let frame = cardFrames[id] {
                dragTouchOffset = CGSize(
                    width: drag.startLocation.x - frame.midX,
                    height: drag.startLocation.y - frame.midY
                )
            }
            didCaptureTouchOffset = true
        }
        dragLocation = drag.location

        // Delete zone check (simple Y threshold).
        let nowOverDelete = drag.location.y > deleteThresholdY
        if nowOverDelete != isOverDeleteZone {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                isOverDeleteZone = nowOverDelete
            }
        }

        // Edge-hold reorder (only when not over delete zone).
        if !nowOverDelete {
            let x = drag.location.x
            let dir: Int
            if x > editorSize.width - edgeHoldZone { dir = 1 }
            else if x < edgeHoldZone { dir = -1 }
            else { dir = 0 }
            setEdgeHold(direction: dir)
        } else {
            setEdgeHold(direction: 0)
        }
    }

    private func handleDragEnded(at location: CGPoint, for id: UUID) {
        setEdgeHold(direction: 0)
        if isOverDeleteZone {
            if let idx = drafts.firstIndex(where: { $0.id == id }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    _ = drafts.remove(at: idx)
                }
            }
        }
        // No release-time reorder — the array order has already been mutated
        // by edge-hold swaps, so whatever position the ghost was in IS final.
        cancelDrag()
    }

    private func cancelDrag() {
        setEdgeHold(direction: 0)
        withAnimation(.easeOut(duration: 0.2)) {
            draggingID = nil
            isOverDeleteZone = false
        }
        dragTouchOffset = .zero
        didCaptureTouchOffset = false
    }

    // MARK: - Edge-hold reorder + auto-scroll

    private func setEdgeHold(direction: Int) {
        guard direction != edgeHoldDirection else { return }
        edgeHoldDirection = direction
        edgeHoldTask?.cancel()
        guard direction != 0 else { return }
        edgeHoldTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(edgeInitialDelayMs))
            while !Task.isCancelled && edgeHoldDirection == direction {
                stepSwap(direction: direction)
                try? await Task.sleep(for: .milliseconds(edgeStepIntervalMs))
            }
        }
    }

    @MainActor
    private func stepSwap(direction: Int) {
        guard let id = draggingID,
              let currentIdx = drafts.firstIndex(where: { $0.id == id }) else { return }
        let targetIdx = currentIdx + direction
        guard targetIdx >= 0 && targetIdx < drafts.count else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            drafts.swapAt(currentIdx, targetIdx)
            // Keep the dragged item's slot visible as it migrates.
            scrollAnchorID = id
        }
    }

    // MARK: - Initial load

    private func loadInitialState() {
        guard drafts.isEmpty else { return }
        switch mode {
        case .create:
            drafts = initialPhotos.map { PhotoDraft(image: $0) }
        case .edit(let collection):
            if title.isEmpty { title = collection.title }
            drafts = collection.orderedPieces.compactMap { piece in
                guard piece.type == .media,
                      let filename = piece.imageFileName,
                      let img = ImageStorage.loadImage(named: filename) else { return nil }
                return PhotoDraft(
                    image: img,
                    existingPieceID: piece.id,
                    existingFilename: filename
                )
            }
        }
    }

    // MARK: - Photo card

    private let maxLandscapeWidth: CGFloat = 300
    private let maxPortraitHeight: CGFloat = 360

    private func cardSize(for image: UIImage) -> CGSize {
        let s = image.size
        guard s.width > 0, s.height > 0 else {
            return CGSize(width: maxLandscapeWidth, height: maxPortraitHeight)
        }
        if s.width >= s.height {
            let w = maxLandscapeWidth
            return CGSize(width: w, height: w * s.height / s.width)
        } else {
            let h = maxPortraitHeight
            return CGSize(width: h * s.width / s.height, height: h)
        }
    }

    private func photoCard(draft: PhotoDraft) -> some View {
        let size = cardSize(for: draft.image)
        return Image(uiImage: draft.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width, height: size.height)
    }

    // MARK: - Add more button

    private var addMoreButton: some View {
        Button {
            morePickerItems = []
            showMorePicker = true
        } label: {
            ZStack {
                Circle()
                    .fill(HallwaysTheme.text)
                    .frame(width: 52, height: 52)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Publish / delete footer

    private var publishFooter: some View {
        let isDragging = draggingID != nil
        let fillColor: Color = isDragging ? deleteColor : HallwaysTheme.text
        let label = isDragging ? "delete" : mode.footerLabel
        let scale: CGFloat = isOverDeleteZone ? 1.6 : 1.0

        return ZStack(alignment: .top) {
            fillColor
                .ignoresSafeArea(edges: .bottom)

            PublishSemicircleShape(
                topCurveHeight: footerTopCurve,
                bottomCurveHeight: 0
            )
            .fill(fillColor)

            Text(label)
                .font(.specialElite(size: 16))
                .foregroundColor(.white)
                .padding(.top, 24)
        }
        .frame(height: footerHeight)
        .scaleEffect(scale, anchor: .bottom)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: scale)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !drafts.isEmpty, !didSave, draggingID == nil else { return }
            didSave = true
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                onSave(displayTitle, drafts)
            }
        }
    }

    private var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Confirmation prompt

    private func confirmPrompt(
        message: String,
        yesLabel: String,
        noLabel: String,
        onYes: @escaping () -> Void,
        onNo: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onNo() }

            VStack(spacing: 20) {
                Text(message)
                    .font(.specialElite(size: 18))
                    .foregroundColor(HallwaysTheme.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Button(action: onYes) {
                        Text(yesLabel)
                            .font(.specialElite(size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(HallwaysTheme.text)
                            )
                    }

                    Button(action: onNo) {
                        Text(noLabel)
                            .font(.specialElite(size: 16))
                            .foregroundColor(HallwaysTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(HallwaysTheme.text, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 280)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(HallwaysTheme.background)
            )
            .padding(.horizontal, 40)
        }
    }

    // MARK: - More photos loading

    private func loadMorePhotos(_ items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                loaded.append(img)
            }
        }
        await MainActor.run {
            let remaining = max(0, maxSelection - drafts.count)
            let toAdd = Array(loaded.prefix(remaining))
            drafts.append(contentsOf: toAdd.map { PhotoDraft(image: $0) })
            morePickerItems = []
        }
    }
}
