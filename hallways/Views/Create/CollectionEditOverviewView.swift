import SwiftUI
import SwiftData
import UIKit

// Edit overview for a combined collection. Owns the in-memory edit state
// for media + text; branches into CreateEditView(.branch) and
// WritingEditorView(.branch) for actual editing. Save persists; X discards.
struct CollectionEditOverviewView: View {
    let collection: Collection
    var onClose: () -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var drafts: [PhotoDraft] = []
    @State private var textContent: String = ""
    @State private var title: String = ""
    @State private var didLoadInitial: Bool = false

    @State private var showMediaBranch: Bool = false
    @State private var showTextBranch: Bool = false
    @State private var showCancelConfirm: Bool = false
    @State private var didSave: Bool = false
    @State private var showSaveCurtain: Bool = false

    private let footerHeight: CGFloat = 40
    private let footerTopCurve: CGFloat = 48

    var body: some View {
        // saveFooter is added via .safeAreaInset(edge: .bottom) — the canonical
        // SwiftUI pattern for a bottom bar, used in CreateEditView. The inset
        // properly reserves a region in the bottom safe area; the inner Color
        // can then extend its paint past the safe-area boundary via
        // .ignoresSafeArea(.bottom) without dragging the parent ZStack's
        // layout frame down with it (the CLAUDE.md gotcha that was causing
        // the `save` label to render inside the home-indicator zone).
        ZStack {
            mainContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    saveFooter
                }

            if showCancelConfirm {
                confirmPrompt(
                    message: "discard changes?",
                    yesLabel: "yes",
                    noLabel: "no",
                    onYes: {
                        showCancelConfirm = false
                        onClose()
                    },
                    onNo: { showCancelConfirm = false }
                )
                .transition(.opacity)
                .zIndex(300)
            }

            if showMediaBranch {
                CreateEditView(
                    mode: .branch(
                        initialDrafts: drafts,
                        onCommit: { newDrafts in
                            drafts = newDrafts
                        }
                    ),
                    initialPhotos: [],
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showMediaBranch = false
                        }
                    },
                    onSave: { _, _, _ in }
                )
                .transition(.opacity)
                .zIndex(400)
            }

            if showTextBranch {
                WritingEditorView(
                    mode: .branch(
                        initialText: textContent,
                        onCommit: { newText in
                            textContent = newText
                        }
                    ),
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showTextBranch = false
                        }
                    },
                    onSave: { _ in }
                )
                .transition(.opacity)
                .zIndex(400)
            }

            if showSaveCurtain {
                PublishCurtainView(
                    label: "save",
                    onRiseComplete: {
                        applyChanges()
                    },
                    onComplete: {
                        showSaveCurtain = false
                        onClose()
                    }
                )
                .zIndex(500)
                .contentShape(Rectangle())
                .onTapGesture { /* swallow */ }
            }
        }
        // Bg via .background() (not as a ZStack child) per CLAUDE.md gotcha:
        // a child with .ignoresSafeArea() expands the ZStack's layout frame to
        // screen edges, which made the save footer at alignment: .bottom anchor
        // at the screen bottom (inside the home-indicator zone) instead of the
        // safe-area boundary. .background() paints to edges without altering
        // the layout frame.
        .background(
            HallwaysTheme.background.ignoresSafeArea()
        )
        .onAppear(perform: loadInitialState)
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            topBar

            VStack(spacing: 0) {
                editMediaTile
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                editTextTile
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Reserve room above the saveFooter for the dome's curve, which
            // bulges 48pt above the saveFooter's frame. Mirrors the carousel
            // padding in CreateEditView (`.padding(.bottom, footerTopCurve + 16)`).
            .padding(.bottom, footerTopCurve + 16)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                if isDirty {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showCancelConfirm = true
                    }
                } else {
                    onClose()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(HallwaysTheme.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Edit media tile

    private var editMediaTile: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showMediaBranch = true
            }
        } label: {
            HStack(spacing: 0) {
                Text("edit media")
                    .font(.specialElite(size: 18))
                    .foregroundColor(HallwaysTheme.text)
                    .frame(maxWidth: .infinity, alignment: .center)

                ZStack {
                    if let first = drafts.first {
                        Image(uiImage: first.image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 220, height: 160)
                            .clipped()
                            .offset(x: 60)
                    } else {
                        Rectangle()
                            .fill(HallwaysTheme.card.opacity(0.5))
                            .frame(width: 220, height: 160)
                            .offset(x: 60)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .clipped()
            }
            .padding(.vertical, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Edit text tile

    private var editTextTile: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showTextBranch = true
            }
        } label: {
            HStack(spacing: 0) {
                Text("edit text")
                    .font(.specialElite(size: 18))
                    .foregroundColor(HallwaysTheme.text)
                    .frame(maxWidth: .infinity, alignment: .center)

                ZStack(alignment: .topLeading) {
                    Image("green-paper-bg")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 220, height: 220)
                        .clipped()
                    Text(textContent.isEmpty ? "[empty]" : textContent)
                        .font(.specialElite(size: 12))
                        .foregroundColor(HallwaysTheme.text)
                        .lineLimit(8)
                        .multilineTextAlignment(.leading)
                        .padding(16)
                        .frame(width: 220, height: 220, alignment: .topLeading)
                }
                .offset(x: 60)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .clipped()
            }
            .padding(.vertical, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save footer

    private var saveFooter: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                HallwaysTheme.text
                    .ignoresSafeArea(edges: .bottom)
                HalfMoonCTA(
                    topCurveHeight: footerTopCurve,
                    bottomCurveHeight: 0
                )
                .fill(HallwaysTheme.text)
            }

            Text("save")
                .font(.specialElite(size: 16))
                .foregroundColor(.white)
                .padding(.top, 24)
        }
        .frame(height: footerHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !didSave else { return }
            didSave = true
            // Trigger the publish-curtain animation. PublishCurtainView's
            // onRiseComplete commits to SwiftData; onComplete dismisses the
            // overview after the curtain exits up off screen.
            showSaveCurtain = true
        }
    }

    // MARK: - State

    private var isDirty: Bool {
        let originalDraftIDs = Set(collection.mediaPieces.map(\.id))
        let currentDraftIDs = Set(drafts.compactMap(\.existingPieceID))
        let mediaChanged = originalDraftIDs != currentDraftIDs
            || drafts.contains(where: { $0.existingPieceID == nil })
        let trimmed = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalText = collection.textPiece?.textContent ?? ""
        return mediaChanged || trimmed != originalText
    }

    private func loadInitialState() {
        guard !didLoadInitial else { return }
        didLoadInitial = true
        title = collection.title
        textContent = collection.textPiece?.textContent ?? ""
        drafts = collection.mediaPieces.compactMap { piece in
            guard let filename = piece.imageFileName,
                  let img = ImageStorage.loadImage(named: filename) else { return nil }
            return PhotoDraft(
                image: img,
                existingPieceID: piece.id,
                existingFilename: filename
            )
        }
    }

    private func applyChanges() {
        let keptMediaIDs = Set(drafts.compactMap(\.existingPieceID))
        let existingByID = Dictionary(
            uniqueKeysWithValues: collection.pieces.map { ($0.id, $0) }
        )

        // Remove media pieces no longer in drafts.
        for piece in collection.pieces where piece.type == .media && !keptMediaIDs.contains(piece.id) {
            if let fn = piece.imageFileName {
                ImageStorage.deleteImage(named: fn)
            }
            modelContext.delete(piece)
        }

        // For each draft: reorder existing, or save new + insert.
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

        // Upsert / delete the text piece.
        let trimmed = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
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

        collection.lastEditedAt = Date()
        try? modelContext.save()
    }

    // MARK: - Confirm prompt

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
}
