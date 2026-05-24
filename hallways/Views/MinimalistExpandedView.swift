import SwiftUI
import UIKit

struct MinimalistExpandedView: View {
    let collection: Collection
    @Environment(\.dismiss) private var dismiss

    @Namespace private var heroNamespace
    @State private var selectedPiece: Piece?

    private let horizontalPadding: CGFloat = 24
    private let portraitWidthRatio: CGFloat = 0.8

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let contentWidth = geo.size.width - (horizontalPadding * 2)
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        ForEach(collection.orderedPieces) { piece in
                            PieceCardView(
                                piece: piece,
                                tiltAngle: 0,
                                cardHeight: nil,
                                cardWidth: width(for: piece, contentWidth: contentWidth)
                            )
                            .frame(maxWidth: .infinity)
                            .matchedGeometryEffect(
                                id: piece.id,
                                in: heroNamespace,
                                isSource: selectedPiece?.id != piece.id
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    selectedPiece = piece
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, horizontalPadding)
                }
            }

            if let piece = selectedPiece {
                ImageViewerView(piece: piece, namespace: heroNamespace) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        selectedPiece = nil
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(collection.title)
                    .font(.specialElite(size: 18))
                    .foregroundColor(HallwaysTheme.text)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(HallwaysTheme.text)
                }
            }
        }
    }

    private func width(for piece: Piece, contentWidth: CGFloat) -> CGFloat {
        if piece.type == .text {
            return contentWidth * portraitWidthRatio
        }
        if let fileName = piece.imageFileName,
           let image = UIImage(named: fileName) {
            return image.size.width >= image.size.height
                ? contentWidth
                : contentWidth * portraitWidthRatio
        }
        return contentWidth
    }
}
