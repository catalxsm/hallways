import SwiftUI

struct PieceCardView: View {
    let piece: Piece
    var tiltAngle: Double? = nil
    var cardHeight: CGFloat? = HallwaysTheme.pieceCardHeight
    var cardWidth: CGFloat? = nil

    private var effectiveTilt: Double {
        tiltAngle ?? piece.tilt
    }

    var body: some View {
        Group {
            if piece.type == .media, let fileName = piece.imageFileName {
                mediaView(fileName: fileName)
            } else if piece.type == .text, let text = piece.textContent {
                textCard(text: text)
            }
        }
        .rotationEffect(.degrees(effectiveTilt))
    }

    @ViewBuilder
    private func mediaView(fileName: String) -> some View {
        let image: Image = {
            if let ui = ImageStorage.loadImage(named: fileName) {
                return Image(uiImage: ui)
            }
            return Image(fileName)
        }()
        let resizable = image
            .resizable()
            .aspectRatio(contentMode: .fit)

        if let width = cardWidth, let height = cardHeight {
            resizable.frame(maxWidth: width, maxHeight: height)
        } else if let width = cardWidth {
            resizable.frame(width: width)
        } else if let height = cardHeight {
            resizable.frame(height: height)
        } else {
            resizable
        }
    }

    private func textCard(text: String) -> some View {
        let (width, height) = textCardSize()
        return ZStack {
            Color(hex: "F5F0E8")

            Text(text)
                .font(.specialElite(size: 14))
                .foregroundColor(HallwaysTheme.text)
                .multilineTextAlignment(.leading)
                .padding(16)
        }
        .frame(width: width, height: height)
    }

    private func textCardSize() -> (CGFloat, CGFloat) {
        if let w = cardWidth, let h = cardHeight {
            return (w, h)
        }
        if let w = cardWidth {
            // Width-only: portrait 3:4
            return (w, w * 4.0 / 3.0)
        }
        if let h = cardHeight {
            // Height-only: square
            return (h, h)
        }
        let fallback = HallwaysTheme.pieceCardHeight
        return (fallback, fallback)
    }
}
