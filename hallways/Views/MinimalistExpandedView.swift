import SwiftUI

struct MinimalistExpandedView: View {
    let collection: Collection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 40) {
                ForEach(collection.orderedPieces) { piece in
                    PieceCardView(
                        piece: piece,
                        tiltAngle: 0,
                        cardHeight: 300
                    )
                    .padding(.horizontal, 30)
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(collection.title)
                    .font(.specialElite(size: 20))
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
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(HallwaysTheme.text)
                }
            }
        }
    }
}
