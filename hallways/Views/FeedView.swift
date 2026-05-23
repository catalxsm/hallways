import SwiftUI
import SwiftData

struct FeedView: View {
    @Query(filter: #Predicate<Piece> { $0.collection == nil },
           sort: \Piece.sortOrder)
    private var standalonePieces: [Piece]

    @Query(sort: \Collection.sortOrder)
    private var collections: [Collection]

    @State private var viewMode: ViewMode = .minimalist
    @State private var selectedCollection: Collection?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main content
                Group {
                    switch viewMode {
                    case .minimalist:
                        MinimalistView(
                            standalonePieces: standalonePieces,
                            collections: collections
                        )
                    case .file:
                        FileView(
                            standalonePieces: standalonePieces,
                            collections: collections,
                            selectedCollection: $selectedCollection
                        )
                    }
                }

                // Bottom bar
                HStack {
                    // Add button
                    Button {
                        // Non-functional for now
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

                    // View mode toggle
                    ViewModeToggle(viewMode: $viewMode)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // File expanded overlay — on top of bottom bar
                if let collection = selectedCollection {
                    FileExpandedView(collection: collection) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedCollection = nil
                        }
                    }
                    .transition(.opacity)
                }
            }
            .navigationDestination(for: Collection.self) { collection in
                MinimalistExpandedView(collection: collection)
            }
        }
    }
}
