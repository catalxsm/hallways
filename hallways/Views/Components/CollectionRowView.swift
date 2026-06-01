import SwiftUI

struct CollectionRowView: View {
    let collection: Collection

    var body: some View {
        let pieces = collection.orderedPieces
        let tiltPattern = HallwaysTheme.collectionTiltPattern
        let scatter = HallwaysTheme.collectionVerticalScatter

        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: HallwaysTheme.overlapOffset) {
                ForEach(Array(pieces.enumerated()), id: \.element.id) { index, piece in
                    let tilt = tiltPattern[index % tiltPattern.count]
                    let yOffset: CGFloat = index.isMultiple(of: 2) ? -scatter : scatter
                    PieceCardView(
                        piece: piece,
                        tiltAngle: tilt,
                        cardHeight: HallwaysTheme.collectionRowHeight
                    )
                    .offset(y: yOffset)
                    .zIndex(Double(index))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, scatter + 12)
        }
    }
}
