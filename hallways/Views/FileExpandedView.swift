import SwiftUI

struct FileExpandedView: View {
    let collection: Collection
    var onDismiss: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            // Darker overlay with minimal blur
            HallwaysTheme.overlay
                .opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 16) {
                Spacer()

                // Collection title
                Text(collection.title)
                    .font(.specialElite(size: 24))
                    .foregroundColor(HallwaysTheme.text)

                // Card with pieces grid
                VStack {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(collection.orderedPieces) { piece in
                            PieceCardView(
                                piece: piece,
                                tiltAngle: 0,
                                cardHeight: 100,
                                cardWidth: 130
                            )
                        }
                    }
                    .padding(20)
                }
                .background(
                    RoundedRectangle(cornerRadius: HallwaysTheme.expandedCardCornerRadius)
                        .fill(HallwaysTheme.card.opacity(HallwaysTheme.cardOpacity))
                )
                .padding(.horizontal, 32)

                // Last edited date
                Text("last edited \(formattedDate)")
                    .font(.specialElite(size: 14))
                    .foregroundColor(HallwaysTheme.text.opacity(0.6))

                Spacer()

                // Reorder button
                Text("reorder collection")
                    .font(.specialElite(size: 16))
                    .foregroundColor(HallwaysTheme.text)
                    .padding(.bottom, 40)
            }
        }
        .background(
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd.yy"
        return formatter.string(from: collection.lastEditedAt)
    }
}
