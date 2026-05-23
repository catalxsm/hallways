import SwiftUI

struct PieceCardView: View {
    let piece: Piece
    var tiltAngle: Double? = nil
    var cardHeight: CGFloat = HallwaysTheme.pieceCardHeight
    var cardWidth: CGFloat? = nil

    private var effectiveTilt: Double {
        tiltAngle ?? piece.tilt
    }

    var body: some View {
        Group {
            if piece.type == .media, let fileName = piece.imageFileName {
                if let width = cardWidth {
                    Image(fileName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: width, maxHeight: cardHeight)
                } else {
                    Image(fileName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: cardHeight)
                }
            } else if piece.type == .text, let text = piece.textContent {
                textCard(text: text)
            }
        }
        .rotationEffect(.degrees(effectiveTilt))
    }

    private func textCard(text: String) -> some View {
        let width = cardWidth ?? cardHeight
        return ZStack {
            Color(hex: "F5F0E8")

            Text(text)
                .font(.specialElite(size: 14))
                .foregroundColor(HallwaysTheme.text)
                .multilineTextAlignment(.leading)
                .padding(16)
        }
        .frame(width: width, height: cardHeight)
    }
}
