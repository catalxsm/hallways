import SwiftUI

struct CollectionStackView: View {
    let collection: Collection
    var size: CGFloat = HallwaysTheme.fileGridItemHeight

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                    .frame(width: size, height: size)

                let pieces = Array(collection.orderedPieces.prefix(3))
                ForEach(Array(pieces.enumerated()), id: \.element.id) { index, piece in
                    PieceCardView(
                        piece: piece,
                        tiltAngle: tiltForIndex(index, total: pieces.count),
                        cardHeight: size * 0.7,
                        cardWidth: size * 0.7
                    )
                    .offset(
                        x: offsetForIndex(index, total: pieces.count).x,
                        y: offsetForIndex(index, total: pieces.count).y
                    )
                    .zIndex(Double(index))
                }
            }
            .frame(width: size, height: size)
            .clipped()

            Text(collection.title)
                .font(.specialElite(size: 14))
                .foregroundColor(HallwaysTheme.text)
                .lineLimit(1)
        }
    }

    private func tiltForIndex(_ index: Int, total: Int) -> Double {
        switch (index, total) {
        case (0, 3): return -5
        case (1, 3): return 4
        case (2, 3): return -2
        case (0, 2): return -4
        case (1, 2): return 3
        default: return 0
        }
    }

    private func offsetForIndex(_ index: Int, total: Int) -> CGPoint {
        switch (index, total) {
        case (0, 3): return CGPoint(x: -8, y: -5)
        case (1, 3): return CGPoint(x: 8, y: 5)
        case (2, 3): return CGPoint(x: -3, y: 10)
        case (0, 2): return CGPoint(x: -6, y: -3)
        case (1, 2): return CGPoint(x: 6, y: 3)
        default: return .zero
        }
    }
}
