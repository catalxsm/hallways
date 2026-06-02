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
    // Sub-screen used by the combined-collection edit overview.
    // No publish/update footer (the dome is permanently the red "delete"
    // drop zone). Back arrow commits drafts to the parent overview.
    case branch(initialDrafts: [PhotoDraft], onCommit: ([PhotoDraft]) -> Void)

    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }

    var isBranch: Bool {
        if case .branch = self { return true }
        return false
    }

    var existingCollection: Collection? {
        if case .edit(let c) = self { return c }
        return nil
    }

    var initialBranchDrafts: [PhotoDraft]? {
        if case .branch(let initial, _) = self { return initial }
        return nil
    }

    var branchCommit: (([PhotoDraft]) -> Void)? {
        if case .branch(_, let commit) = self { return commit }
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

private struct EditorFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private let editorSpace = "editor"
private let deleteColor = Color(hex: "9B1515")
private let deleteActiveColor = Color(hex: "A11111")

struct CreateEditView: View {
    let mode: EditorMode
    let initialPhotos: [UIImage]
    var onCancel: () -> Void
    // textContent is the writing attached to this collection (nil if none).
    // Set in .create mode by the carousel-end "writing" chooser, or loaded
    // from collection.textPiece in .edit mode.
    var onSave: (_ title: String, _ drafts: [PhotoDraft], _ textContent: String?) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var drafts: [PhotoDraft] = []
    @State private var title: String = ""
    @State private var showCancelConfirm: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var morePickerItems: [PhotosPickerItem] = []
    @State private var showMorePicker: Bool = false
    @State private var showCarouselEndChooser: Bool = false
    @State private var showWritingSubEditor: Bool = false
    @State private var draftText: String? = nil
    @State private var didSave: Bool = false

    // Custom drag state.
    @State private var draggingID: UUID? = nil
    @State private var dragLocation: CGPoint = .zero          // in editor coords
    @State private var dragTouchOffset: CGSize = .zero
    @State private var cardFrames: [UUID: CGRect] = [:]       // in editor coords
    @State private var editorSize: CGSize = .zero
    @State private var editorGlobalFrame: CGRect = .zero      // in window coords
    @State private var isOverDeleteZone: Bool = false

    // Edge auto-scroll state.
    @State private var autoScrollDirection: Int = 0
    @State private var autoScrollTask: Task<Void, Never>? = nil
    @State private var scrollAnchorID: UUID? = nil

    private let footerHeight: CGFloat = 40
    private let footerTopCurve: CGFloat = 48
    private let maxSelection: Int = 10
    private let titlePlaceholder: String = "[untitled collection]"

    // Only the very edge of the carousel triggers auto-scroll.
    private let edgeAutoScrollZone: CGFloat = 30
    private let autoScrollInitialDelayMs: Int = 250
    private let autoScrollIntervalMs: Int = 700

    private var deleteThresholdY: CGFloat {
        // Only the bottom 25% triggers delete — deep enough that mid-screen
        // dragging never trips it.
        editorSize.height * 0.75
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

                if showCarouselEndChooser {
                    CreateOverlay(
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCarouselEndChooser = false
                            }
                        },
                        onUploadMedia: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCarouselEndChooser = false
                            }
                            morePickerItems = []
                            // Defer to let the chooser dismiss animation start
                            // before the PhotosPicker presents.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showMorePicker = true
                            }
                        },
                        onWriting: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCarouselEndChooser = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showWritingSubEditor = true
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(310)
                }

                if showWritingSubEditor {
                    WritingEditorView(
                        mode: .branch(
                            initialText: draftText ?? "",
                            onCommit: { content in
                                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                                draftText = trimmed.isEmpty ? nil : trimmed
                            }
                        ),
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showWritingSubEditor = false
                            }
                        },
                        onSave: { _ in }
                    )
                    .transition(.opacity)
                    .zIndex(320)
                }
            }
            .coordinateSpace(name: editorSpace)
            .background(
                GeometryReader { innerGeo in
                    Color.clear
                        .preference(key: EditorFrameKey.self, value: innerGeo.frame(in: .global))
                }
            )
            .onPreferenceChange(EditorFrameKey.self) { editorGlobalFrame = $0 }
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
                if mode.isBranch {
                    mode.branchCommit?(drafts)
                    onCancel()
                } else {
                    showCancelConfirm = true
                }
            } label: {
                Image(systemName: mode.isBranch ? "chevron.left" : "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(HallwaysTheme.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            if mode.isBranch {
                Spacer()
            } else {
                TextField(titlePlaceholder, text: $title)
                    .font(.specialElite(size: 18))
                    .foregroundColor(HallwaysTheme.text)
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
            }

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
            .gesture(
                CardLongPressGesture(
                    onBegan: { globalPoint in
                        beginDrag(id: draft.id, globalPoint: globalPoint)
                    },
                    onChanged: { globalPoint in
                        updateDrag(id: draft.id, globalPoint: globalPoint)
                    },
                    onEnded: { globalPoint in
                        endDrag(id: draft.id, globalPoint: globalPoint)
                    },
                    onCancelled: {
                        cancelDrag()
                    }
                )
            )
    }

    // MARK: - Drag handlers

    private func beginDrag(id: UUID, globalPoint: CGPoint) {
        guard draggingID == nil else { return }
        let editorPoint = toEditor(globalPoint)
        let cardFrame = cardFrames[id]
        // Offset between touch and the card's center so the ghost sticks where
        // the user grabbed it, not jumping to center.
        let offset: CGSize = cardFrame.map { frame in
            CGSize(
                width: editorPoint.x - frame.midX,
                height: editorPoint.y - frame.midY
            )
        } ?? .zero
        dragLocation = editorPoint
        dragTouchOffset = offset
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            draggingID = id
        }
    }

    private func updateDrag(id: UUID, globalPoint: CGPoint) {
        guard draggingID == id else { return }
        let editorPoint = toEditor(globalPoint)
        dragLocation = editorPoint

        let nowOverDelete = editorPoint.y > deleteThresholdY
        if nowOverDelete != isOverDeleteZone {
            withAnimation(.easeOut(duration: 0.22)) {
                isOverDeleteZone = nowOverDelete
            }
        }

        if nowOverDelete {
            setAutoScroll(direction: 0)
            return
        }

        // Instagram-style real-time reorder: if the finger is over another
        // card's frame, swap the dragged item into that slot.
        reorderIfHovering(at: editorPoint, draggedID: id)

        // Edge auto-scroll only at the very edge of the carousel.
        let x = editorPoint.x
        let dir: Int
        if x > editorSize.width - edgeAutoScrollZone { dir = 1 }
        else if x < edgeAutoScrollZone { dir = -1 }
        else { dir = 0 }
        setAutoScroll(direction: dir)
    }

    private func endDrag(id: UUID, globalPoint: CGPoint) {
        setAutoScroll(direction: 0)
        if isOverDeleteZone {
            if let idx = drafts.firstIndex(where: { $0.id == id }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    _ = drafts.remove(at: idx)
                }
            }
        }
        cancelDrag()
    }

    private func cancelDrag() {
        setAutoScroll(direction: 0)
        withAnimation(.easeOut(duration: 0.2)) {
            draggingID = nil
            isOverDeleteZone = false
        }
        dragTouchOffset = .zero
    }

    private func reorderIfHovering(at editorPoint: CGPoint, draggedID: UUID) {
        guard let currentIdx = drafts.firstIndex(where: { $0.id == draggedID }) else { return }
        for (idx, draft) in drafts.enumerated() where draft.id != draggedID {
            guard let frame = cardFrames[draft.id] else { continue }
            // Only check X (horizontal carousel) — finger can wander vertically
            // without canceling the hover.
            if editorPoint.x >= frame.minX && editorPoint.x <= frame.maxX {
                if currentIdx != idx {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        let item = drafts.remove(at: currentIdx)
                        drafts.insert(item, at: idx)
                    }
                }
                return
            }
        }
    }

    private func toEditor(_ globalPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: globalPoint.x - editorGlobalFrame.minX,
            y: globalPoint.y - editorGlobalFrame.minY
        )
    }

    // MARK: - Edge auto-scroll

    private func setAutoScroll(direction: Int) {
        guard direction != autoScrollDirection else { return }
        autoScrollDirection = direction
        autoScrollTask?.cancel()
        guard direction != 0 else { return }
        autoScrollTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(autoScrollInitialDelayMs))
            while !Task.isCancelled && autoScrollDirection == direction {
                stepAutoScroll(direction: direction)
                try? await Task.sleep(for: .milliseconds(autoScrollIntervalMs))
            }
        }
    }

    @MainActor
    private func stepAutoScroll(direction: Int) {
        guard let id = draggingID,
              let currentIdx = drafts.firstIndex(where: { $0.id == id }) else { return }
        // Scroll to neighbor of the dragged item — reveals off-screen cards
        // so hover-reorder can target them.
        let neighborIdx = currentIdx + direction
        guard neighborIdx >= 0 && neighborIdx < drafts.count else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            scrollAnchorID = drafts[neighborIdx].id
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
            if let existing = collection.textPiece?.textContent,
               !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draftText = existing
            }
        case .branch(let initial, _):
            drafts = initial
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
            // In branch mode, no chooser — branch only edits existing drafts.
            // Otherwise show the media/writing chooser; the user picks one or
            // the other for this add action.
            if mode.isBranch {
                morePickerItems = []
                showMorePicker = true
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCarouselEndChooser = true
                }
            }
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
        let isBranch = mode.isBranch
        let showsDelete = isDragging || isBranch
        let fillColor: Color = showsDelete
            ? (isOverDeleteZone ? deleteActiveColor : deleteColor)
            : HallwaysTheme.text
        let label = showsDelete ? "delete" : mode.footerLabel
        let scale: CGFloat = isOverDeleteZone ? 1.6 : 1.0

        return ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                fillColor
                    .ignoresSafeArea(edges: .bottom)

                HalfMoonCTA(
                    topCurveHeight: footerTopCurve,
                    bottomCurveHeight: 0
                )
                .fill(fillColor)
            }
            .scaleEffect(scale, anchor: .bottom)
            .animation(.easeOut(duration: 0.22), value: scale)

            Text(label)
                .font(.specialElite(size: 16))
                .foregroundColor(.white)
                .padding(.top, 24)
        }
        .frame(height: footerHeight)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .animation(.easeOut(duration: 0.22), value: isOverDeleteZone)
        .contentShape(Rectangle())
        .onTapGesture {
            // In branch mode the dome is the delete drop zone, not a publish
            // button — tapping does nothing here.
            guard !mode.isBranch else { return }
            guard !drafts.isEmpty, !didSave, draggingID == nil else { return }
            didSave = true
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                onSave(displayTitle, drafts, draftText)
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

// MARK: - UIKit-bridged long-press recognizer

// Wraps UILongPressGestureRecognizer so it coexists naturally with the
// ScrollView's pan: quick movement fails the long press (scroll wins),
// stillness for `minimumPressDuration` triggers .began (drag mode wins).
private struct CardLongPressGesture: UIGestureRecognizerRepresentable {
    let onBegan: (CGPoint) -> Void
    let onChanged: (CGPoint) -> Void
    let onEnded: (CGPoint) -> Void
    let onCancelled: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Void { () }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.2
        recognizer.allowableMovement = 15
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {}

    func handleUIGestureRecognizerAction(
        _ recognizer: UILongPressGestureRecognizer,
        context: Context
    ) {
        let location = recognizer.location(in: nil)
        switch recognizer.state {
        case .began:
            onBegan(location)
        case .changed:
            onChanged(location)
        case .ended:
            onEnded(location)
        case .cancelled, .failed:
            onCancelled()
        default:
            break
        }
    }
}
