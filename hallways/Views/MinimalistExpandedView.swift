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

    // Pull-down edit CTA reveal state.
    @State private var editRevealProgress: CGFloat = 0

    private let editCTAHeight: CGFloat = 100
    private let editCTABottomCurve: CGFloat = 72
    private let revealThreshold: CGFloat = 60

    private struct UpdatePayload: Equatable {
        let title: String
        let drafts: [PhotoDraft]
        let textContent: String?
        static func == (lhs: UpdatePayload, rhs: UpdatePayload) -> Bool {
            lhs.title == rhs.title
                && lhs.drafts.map(\.id) == rhs.drafts.map(\.id)
                && lhs.textContent == rhs.textContent
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

                        }
                        .padding(.top, 80) // Room for the top-trailing header.
                        .padding(.bottom, 16)
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
                    onSave: { title, drafts, textContent in
                        updatePayload = UpdatePayload(
                            title: title,
                            drafts: drafts,
                            textContent: textContent
                        )
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
                        applyUpdate(
                            title: payload.title,
                            drafts: payload.drafts,
                            textContent: payload.textContent
                        )
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

            // Top header row — back arrow on left + title/date on right.
            // Matches CombinedExpandedView's header.
            HStack(alignment: .center) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(HallwaysTheme.text)
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(collection.title.isEmpty ? "[untitled collection]" : collection.title)
                        .font(.specialElite(size: 16))
                        .foregroundColor(HallwaysTheme.text)
                        .lineLimit(1)
                    Text(collection.lastEditedAt.hallwaysStamp)
                        .font(.printvetica(size: 12))
                        .foregroundColor(Color(hex: "9F9F9F"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .opacity(selectedPiece == nil && !showEditor ? 1 : 0)
            .zIndex(40)

            // Pull-down drag strip — covers the top area except the left 60pt
            // where the back-arrow tap zone lives. Touches in the back-arrow
            // zone pass through; drags elsewhere reveal the edit CTA.
            HStack(spacing: 0) {
                Color.clear.frame(width: 60) // back-arrow tap zone
                Color.clear
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .highPriorityGesture(revealDragGesture)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(selectedPiece == nil && !showEditor)
            .zIndex(45)

            editCTA
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(editRevealProgress > 0.01)
                .zIndex(60)

            if editRevealProgress > 0.01 && !showEditor {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            editRevealProgress = 0
                        }
                    }
                    .zIndex(55)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Edit CTA + reveal gesture

    private var editCTA: some View {
        let domeTotal = editCTAHeight + editCTABottomCurve
        // +100 buffer guarantees the curve's bottom edge clears the safe-area
        // boundary even on tall-status-bar devices — prevents a sliver peeking
        // at rest. Mirrors the formula in CombinedExpandedView.
        let hiddenOffset: CGFloat = -(domeTotal + 100)
        let translateY: CGFloat = hiddenOffset * (1 - editRevealProgress)
        return ZStack(alignment: .top) {
            HalfMoonCTA(
                topCurveHeight: 0,
                bottomCurveHeight: editCTABottomCurve
            )
            .fill(HallwaysTheme.text)
            .frame(height: editCTAHeight)
            .ignoresSafeArea(edges: .top)

            Text("edit")
                .font(.specialElite(size: 16))
                .foregroundColor(.white)
                .padding(.top, 40)
        }
        .frame(height: editCTAHeight)
        .offset(y: translateY)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                editRevealProgress = 0
                showEditor = true
            }
        }
    }

    private var revealDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let dy = max(0, value.translation.height)
                editRevealProgress = min(1, dy / (revealThreshold * 2))
            }
            .onEnded { value in
                if value.translation.height > revealThreshold {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        editRevealProgress = 1
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        editRevealProgress = 0
                    }
                }
            }
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

    private func width(for piece: Piece, contentWidth: CGFloat) -> CGFloat {
        if piece.type == .text {
            return contentWidth * portraitWidthRatio
        }
        if let fileName = piece.imageFileName,
           let size = ImageStorage.imageSize(named: fileName) {
            return size.width >= size.height
                ? contentWidth
                : contentWidth * portraitWidthRatio
        }
        return contentWidth
    }

    // MARK: - Persistence

    private func applyUpdate(title: String, drafts: [PhotoDraft], textContent: String?) {
        let keptMediaIDs = Set(drafts.compactMap(\.existingPieceID))
        let existingByID = Dictionary(uniqueKeysWithValues: collection.pieces.map { ($0.id, $0) })

        // Remove media pieces no longer present in drafts.
        for piece in collection.pieces where piece.type == .media && !keptMediaIDs.contains(piece.id) {
            if let fn = piece.imageFileName {
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

        // Upsert / delete the attached text piece based on the incoming content.
        let trimmed = textContent?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            if let existing = collection.textPiece {
                existing.textContent = trimmed
                existing.sortOrder = drafts.count
            } else {
                let textPiece = Piece(
                    type: .text,
                    textContent: trimmed,
                    sortOrder: drafts.count
                )
                collection.pieces.append(textPiece)
            }
        } else if let existing = collection.textPiece {
            modelContext.delete(existing)
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
