import SwiftUI
import SwiftData

struct MinimalistView: View {
    let standalonePieces: [Piece]
    let collections: [Collection]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 40) {
                // Standalone pieces
                ForEach(standalonePieces) { piece in
                    PieceCardView(
                        piece: piece,
                        tiltAngle: piece.tilt,
                        cardHeight: HallwaysTheme.minimalistRowHeight
                    )
                    .padding(.horizontal, 16)
                }

                // Collections as horizontal rows
                ForEach(collections) { collection in
                    NavigationLink(value: collection) {
                        CollectionRowView(collection: collection)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 60)
        }
    }
}
