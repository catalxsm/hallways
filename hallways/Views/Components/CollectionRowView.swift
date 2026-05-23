import SwiftUI

struct CollectionRowView: View {
    let collection: Collection

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HallwaysTheme.overlapOffset) {
                ForEach(Array(collection.orderedPieces.enumerated()), id: \.element.id) { index, piece in
                    let magnitude = max(abs(piece.tilt), 1.5)
                    let tilt = index.isMultiple(of: 2) ? magnitude : -magnitude
                    PieceCardView(
                        piece: piece,
                        tiltAngle: tilt,
                        cardHeight: HallwaysTheme.collectionRowHeight
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
