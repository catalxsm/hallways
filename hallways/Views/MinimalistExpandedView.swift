import SwiftUI
import SwiftData
import UIKit

struct MinimalistExpandedView: View {
    let collection: Collection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Namespace private var heroNamespace
    @State private var selectedPiece: Piece?
    // Tracks the last piece the user opened. Stays set during the exit
    // animation so the card can render above its siblings while flying back.
    @State private var lastInteractedID: UUID? = nil

    // Edit flow state.
    @State private var showEditor: Bool = false
    @State private var updatePayload: UpdatePayload? = nil

    private struct UpdatePayload: Equatable {
        let title: String
        let drafts: [PhotoDraft]
        static func == (lhs: UpdatePayload, rhs: UpdatePayload) -> Bool {
            lhs.title == rhs.title && lhs.drafts.map(\.id) == rhs.drafts.map(\.id)
        }
    }

    private let horizontalPadding: CGFloat = 24
    private let portraitWidthRatio: CGFloat = 0.8

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let contentWidth = geo.size.width - (horizontalPadding * 2)
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 24) {
                            ForEach(collection.orderedPieces) { piece in
                                PieceCardView(
                                    piece: piece,
                                    tiltAngle: 0,
                                    cardHeight: nil,
                                    cardWidth: width(for: piece, contentWidth: contentWidth)
                                )
                                .frame(maxWidth: .infinity)
                                .matchedGeometryEffect(
                                    id: piece.id,
                                    in: heroNamespace,
                                    isSource: selectedPiece?.id != piece.id
                                )
                                .zIndex(lastInteractedID == piece.id ? 100 : 0)
                                .id(piece.id)
                                .onTapGesture {
                                    lastInteractedID = piece.id
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        selectedPiece = piece
                                    }
                                }
                            }

                            Text(formattedLastEdited)
                                .font(.printvetica(size: 14))
                                .foregroundColor(Color(hex: "9F9F9F"))
                                .frame(maxWidth: .infinity, alignment: .center)
                                // 24 from LazyVStack spacing + 8 padding = 32pt from last photo.
                                .padding(.top, 8)
                                .padding(.bottom, 16)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, horizontalPadding)
                    }
                    .onChange(of: selectedPiece?.id) { _, newID in
                        // Keep the source card on screen as the user swipes between
                        // photos in the viewer, so the hero exit has a real target.
                        guard let id = newID else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }

            // Edge-swipe-back: an invisible strip on the left edge that pops
            // the view when the user drags right from the very edge.
            // Only active when no overlay is presented.
            if selectedPiece == nil && !showEditor {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: 20)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { value in
                                    if value.translation.width > 60 &&
                                        abs(value.translation.width) > abs(value.translation.height) {
                                        dismiss()
                                    }
                                }
                        )
                    Spacer()
                }
                .ignoresSafeArea()
                .zIndex(50)
            }

            if selectedPiece != nil {
                ImageViewerView(
                    pieces: collection.orderedPieces,
                    selectedPiece: viewerBinding,
                    namespace: heroNamespace
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        selectedPiece = nil
                    }
                    // Keep the card on top until the hero animation finishes.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        lastInteractedID = nil
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }

            if showEditor {
                CreateEditView(
                    mode: .edit(collection),
                    initialPhotos: [],
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showEditor = false
                        }
                    },
                    onSave: { title, drafts in
                        updatePayload = UpdatePayload(title: title, drafts: drafts)
                    },
                    onDelete: {
                        deleteCollection()
                    }
                )
                .transition(.opacity)
                .zIndex(2)
            }

            if let payload = updatePayload {
                PublishCurtainView(
                    label: "update",
                    onRiseComplete: {
                        applyUpdate(title: payload.title, drafts: payload.drafts)
                        showEditor = false
                    },
                    onComplete: {
                        updatePayload = nil
                    }
                )
                .zIndex(3)
                .contentShape(Rectangle())
                .onTapGesture { /* swallow */ }
            }
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(chromeVisibility, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(collection.title)
                    .font(.specialElite(size: 18))
                    .foregroundColor(HallwaysTheme.text)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(HallwaysTheme.text)
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showEditor = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(HallwaysTheme.text)
                        .frame(width: 44, height: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    private var chromeVisibility: Visibility {
        (selectedPiece != nil || showEditor) ? .hidden : .visible
    }

    // Keeps lastInteractedID in sync with whatever piece the viewer is showing
    // (so the hero exit lands on top of the correct sibling after a swipe).
    private var viewerBinding: Binding<Piece?> {
        Binding(
            get: { selectedPiece },
            set: { newValue in
                selectedPiece = newValue
                if let id = newValue?.id {
                    lastInteractedID = id
                }
            }
        )
    }

    private var formattedLastEdited: String {
        let date = collection.lastEditedAt
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy.MM.dd"

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "en_US_POSIX")
        weekdayFormatter.dateFormat = "EEE"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        let dateStr = dateFormatter.string(from: date)
        let weekday = weekdayFormatter.string(from: date).uppercased()
        let timeStr = timeFormatter.string(from: date)

        return "\(dateStr)   |   \(weekday) \(timeStr)"
    }

    private func width(for piece: Piece, contentWidth: CGFloat) -> CGFloat {
        if piece.type == .text {
            return contentWidth * portraitWidthRatio
        }
        if let fileName = piece.imageFileName,
           let image = ImageStorage.loadImage(named: fileName) {
            return image.size.width >= image.size.height
                ? contentWidth
                : contentWidth * portraitWidthRatio
        }
        return contentWidth
    }

    // MARK: - Persistence

    private func applyUpdate(title: String, drafts: [PhotoDraft]) {
        let keptIDs = Set(drafts.compactMap(\.existingPieceID))
        let existingByID = Dictionary(uniqueKeysWithValues: collection.pieces.map { ($0.id, $0) })

        // Remove pieces no longer present in drafts.
        for piece in collection.pieces where !keptIDs.contains(piece.id) {
            if let fn = piece.imageFileName, piece.type == .media {
                ImageStorage.deleteImage(named: fn)
            }
            modelContext.delete(piece)
        }

        // For each draft, either reorder existing or create new.
        for (index, draft) in drafts.enumerated() {
            if let pid = draft.existingPieceID, let piece = existingByID[pid] {
                piece.sortOrder = index
            } else {
                guard let filename = try? ImageStorage.saveJPEG(draft.image) else { continue }
                let piece = Piece(
                    type: .media,
                    imageFileName: filename,
                    sortOrder: index
                )
                collection.pieces.append(piece)
            }
        }

        collection.title = title
        collection.lastEditedAt = Date()
        try? modelContext.save()
    }

    private func deleteCollection() {
        for piece in collection.pieces {
            if let fn = piece.imageFileName, piece.type == .media {
                ImageStorage.deleteImage(named: fn)
            }
        }
        modelContext.delete(collection)
        try? modelContext.save()
        dismiss()
    }
}
