import SwiftUI
import SwiftData

struct FileView: View {
    let standalonePieces: [Piece]
    let collections: [Collection]
    @Binding var selectedCollection: Collection?

    private let columns = [
        GridItem(.flexible(), spacing: HallwaysTheme.gridSpacing),
        GridItem(.flexible(), spacing: HallwaysTheme.gridSpacing)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("sort by")
                    .font(.specialElite(size: 16))
                    .foregroundColor(HallwaysTheme.text)
                Spacer()
                Text("edit")
                    .font(.specialElite(size: 16))
                    .foregroundColor(HallwaysTheme.text)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 24) {
                    // Standalone pieces
                    ForEach(standalonePieces) { piece in
                        standaloneItem(piece: piece)
                    }

                    // Collections
                    ForEach(collections) { collection in
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedCollection = collection
                            }
                        } label: {
                            CollectionStackView(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 80)
            }
        }
    }

    private func standaloneItem(piece: Piece) -> some View {
        VStack(spacing: 8) {
            if piece.type == .media, let fileName = piece.imageFileName {
                Image(fileName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: HallwaysTheme.fileGridItemHeight)
            }

            Text(piece.imageFileName ?? "untitled")
                .font(.specialElite(size: 12))
                .foregroundColor(HallwaysTheme.text)
                .lineLimit(1)
        }
    }
}
