import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Piece> { $0.collection == nil },
           sort: \Piece.sortOrder)
    private var standalonePieces: [Piece]

    @Query(sort: \Collection.sortOrder)
    private var collections: [Collection]

    @State private var viewMode: ViewMode = .minimalist
    @State private var selectedCollection: Collection?

    // Create flow state.
    @State private var showCreateOverlay: Bool = false
    @State private var showInitialPicker: Bool = false
    @State private var initialPickerItems: [PhotosPickerItem] = []
    @State private var editingPhotos: [UIImage]? = nil
    @State private var publishingPayload: PublishingPayload? = nil

    // Writing flow state.
    @State private var showWritingCreate: Bool = false
    @State private var editingTextPiece: Piece? = nil
    @State private var publishingText: PublishingText? = nil

    private struct PublishingPayload: Equatable {
        let title: String
        let images: [UIImage]
    }

    private struct PublishingText: Equatable {
        let content: String
        let editingPieceID: UUID?

        var label: String { editingPieceID == nil ? "publish" : "save" }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main content
                Group {
                    switch viewMode {
                    case .minimalist:
                        MinimalistView(collections: collections)
                    case .file:
                        FileView(
                            standalonePieces: standalonePieces,
                            collections: collections,
                            selectedCollection: $selectedCollection,
                            onEditTextPiece: { piece in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    editingTextPiece = piece
                                }
                            }
                        )
                    }
                }

                // Bottom bar
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showCreateOverlay = true
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

                    Spacer()

                    ViewModeToggle(viewMode: $viewMode)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // File expanded overlay
                if let collection = selectedCollection {
                    FileExpandedView(collection: collection) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedCollection = nil
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }

                // Create overlay (white blur with upload media / writing)
                if showCreateOverlay {
                    CreateOverlay(
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showCreateOverlay = false
                            }
                        },
                        onUploadMedia: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCreateOverlay = false
                            }
                            initialPickerItems = []
                            // Slight delay so the picker presents over the cleared overlay.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                showInitialPicker = true
                            }
                        },
                        onWriting: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCreateOverlay = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showWritingCreate = true
                                }
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(2)
                }

                // CreateEditView shown once initial photos are selected.
                if let photos = editingPhotos {
                    CreateEditView(
                        mode: .create,
                        initialPhotos: photos,
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                editingPhotos = nil
                            }
                        },
                        onSave: { title, drafts in
                            publishingPayload = PublishingPayload(
                                title: title,
                                images: drafts.map { $0.image }
                            )
                        }
                    )
                    .transition(.opacity)
                    .zIndex(3)
                }

                // Writing editor — create mode.
                if showWritingCreate {
                    WritingEditorView(
                        mode: .create,
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showWritingCreate = false
                            }
                        },
                        onSave: { content in
                            publishingText = PublishingText(
                                content: content,
                                editingPieceID: nil
                            )
                        }
                    )
                    .transition(.opacity)
                    .zIndex(3)
                }

                // Writing editor — edit mode.
                if let piece = editingTextPiece {
                    WritingEditorView(
                        mode: .edit(piece),
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                editingTextPiece = nil
                            }
                        },
                        onSave: { content in
                            publishingText = PublishingText(
                                content: content,
                                editingPieceID: piece.id
                            )
                        }
                    )
                    .transition(.opacity)
                    .zIndex(3)
                }

                // Publish curtain (absorbs taps during animation).
                if let payload = publishingPayload {
                    PublishCurtainView(
                        onRiseComplete: {
                            publish(title: payload.title, images: payload.images)
                            editingPhotos = nil
                        },
                        onComplete: {
                            publishingPayload = nil
                        }
                    )
                    .zIndex(4)
                    .contentShape(Rectangle())
                    .onTapGesture { /* swallow */ }
                }

                if let payload = publishingText {
                    PublishCurtainView(
                        label: payload.label,
                        onRiseComplete: {
                            persistText(payload: payload)
                            showWritingCreate = false
                            editingTextPiece = nil
                        },
                        onComplete: {
                            publishingText = nil
                        }
                    )
                    .zIndex(4)
                    .contentShape(Rectangle())
                    .onTapGesture { /* swallow */ }
                }
            }
            .navigationDestination(for: Collection.self) { collection in
                MinimalistExpandedView(collection: collection)
            }
        }
        .photosPicker(
            isPresented: $showInitialPicker,
            selection: $initialPickerItems,
            maxSelectionCount: 10,
            selectionBehavior: .ordered,
            matching: .images
        )
        .onChange(of: initialPickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadInitialPhotos(items) }
        }
    }

    // MARK: - Photo loading

    private func loadInitialPhotos(_ items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                loaded.append(img)
            }
        }
        await MainActor.run {
            initialPickerItems = []
            guard !loaded.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                editingPhotos = loaded
            }
        }
    }

    // MARK: - Persist published collection

    private func persistText(payload: PublishingText) {
        let trimmed = payload.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let pieceID = payload.editingPieceID,
           let piece = (try? modelContext.fetch(FetchDescriptor<Piece>()))?
            .first(where: { $0.id == pieceID }) {
            piece.textContent = trimmed
        } else {
            let collectionMin = collections.map(\.sortOrder).min() ?? 0
            let standaloneMin = standalonePieces.map(\.sortOrder).min() ?? 0
            let nextSort = min(collectionMin, standaloneMin) - 1
            let piece = Piece(
                type: .text,
                textContent: trimmed,
                sortOrder: nextSort
            )
            modelContext.insert(piece)
        }
        try? modelContext.save()
        viewMode = .file
    }

    private func publish(title: String, images: [UIImage]) {
        var pieces: [Piece] = []
        for (index, image) in images.enumerated() {
            guard let filename = try? ImageStorage.saveJPEG(image) else { continue }
            let piece = Piece(
                type: .media,
                imageFileName: filename,
                sortOrder: index
            )
            pieces.append(piece)
        }
        let minSort = collections.map(\.sortOrder).min() ?? 0
        let collection = Collection(
            title: title,
            pieces: pieces,
            lastEditedAt: Date(),
            sortOrder: minSort - 1
        )
        modelContext.insert(collection)
        try? modelContext.save()
    }
}
