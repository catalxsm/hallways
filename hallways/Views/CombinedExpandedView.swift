import SwiftUI
import SwiftData
import UIKit

// Top-level layout for a Collection that has BOTH media and a text piece.
// Routed to from FeedView when `collection.isCombined` is true.
//
// Layout (non-scrolling at the root):
//   - top-right header: title + date stamp
//   - upper region:     horizontal media row
//   - lower region:     fixed parchment text card with internal vertical scroll
//   - reveals a top-anchored HalfMoonCTA "edit" CTA on pull-down.
struct CombinedExpandedView: View {
    let collection: Collection
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPiece: Piece? = nil
    @State private var lastInteractedID: UUID? = nil
    @State private var showEditOverview: Bool = false

    // Edit CTA reveal state. 0 = hidden above screen, 1 = fully revealed.
    @State private var editRevealProgress: CGFloat = 0
    @State private var isDraggingReveal: Bool = false

    @Namespace private var heroNamespace

    private let headerRowHeight: CGFloat = 72
    private let editCTAHeight: CGFloat = 100
    private let editCTABottomCurve: CGFloat = 72
    private let revealThreshold: CGFloat = 60

    var body: some View {
        ZStack {
            // Body-level GeometryReader so we can hand each region an EXPLICIT
            // half-height frame. With both regions only set to maxHeight: .infinity,
            // SwiftUI's VStack hands the green-paper textRegion its (huge) ideal
            // size first and starves mediaRow to ~0pt. Explicit frames bypass
            // ideal-size negotiation entirely.
            //
            // Background is on .background() (not a ZStack child) per CLAUDE.md
            // gotcha: an .ignoresSafeArea() child pushes the ZStack's layout
            // frame to screen edges and warps the GeometryReader's reported size.
            GeometryReader { geo in
                // 60/40 split below the header — text region (60%) is taller
                // than media row (40%) per design.
                let availableHeight = max(0, geo.size.height - headerRowHeight)
                let mediaHeight = availableHeight * 0.4
                let textHeight = availableHeight * 0.6
                VStack(spacing: 0) {
                    topHeaderRow
                        .frame(height: headerRowHeight)
                        .padding(.horizontal, 16)

                    // cardHeight accounts for 12pt top + 32pt bottom of vertical
                    // padding inside the ScrollView, leaving breathing room
                    // between the photos and the text region below.
                    mediaRow(cardHeight: max(80, mediaHeight - 44))
                        .frame(height: mediaHeight)

                    textRegion
                        .frame(height: textHeight)
                        // Extend the parchment paint past the bottom safe area
                        // so the text region visually reaches the screen edge.
                        // .background() paints without altering layout, so this
                        // does NOT push the parent ZStack's frame out (unlike
                        // putting .ignoresSafeArea on the body).
                        .background(
                            Color(hex: "E8E0C8").ignoresSafeArea(edges: .bottom)
                        )
                }
            }

            // Pull-down drag receiver — overlays the title/date side of the
            // header row (back-arrow zone on the left is excluded so taps
            // still work). Starting the drag here and moving down reveals
            // the edit CTA.
            HStack(spacing: 0) {
                Color.clear.frame(width: 60) // back-arrow tap zone passes through
                Color.clear
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .highPriorityGesture(revealDragGesture)
            }
            .frame(height: headerRowHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(!showEditOverview)

            // Edit CTA, anchored above the screen and slid down by reveal progress.
            editCTA
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(editRevealProgress > 0.01)
                .zIndex(60)

            // Backstop tap-to-dismiss CTA when revealed.
            if editRevealProgress > 0.01 && !showEditOverview {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { collapseEditCTA() }
                    .zIndex(55)
            }

            if let piece = selectedPiece {
                ImageViewerView(
                    pieces: collection.mediaPieces,
                    selectedPiece: viewerBinding,
                    namespace: heroNamespace
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        selectedPiece = nil
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        lastInteractedID = nil
                    }
                }
                .transition(.opacity)
                .zIndex(80)
                .ignoresSafeArea()
                .id(piece.id)
            }

            if showEditOverview {
                CollectionEditOverviewView(
                    collection: collection,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showEditOverview = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(200)
            }
        }
        // textRegion's parchment paint is extended past the bottom safe area
        // via a .background() modifier on the textRegion itself (see below) —
        // NOT via .ignoresSafeArea on this ZStack. Why: ignoresSafeArea here
        // propagates into the CollectionEditOverviewView ZStack-child overlay
        // and makes its .safeAreaInset(.bottom) anchor at the screen edge
        // instead of above the home indicator. Keeping the body's safe area
        // intact lets the overlay's saveFooter sit cleanly above the home
        // indicator while still letting the textRegion paint to the screen
        // bottom via its own scoped background.
        .background(
            HallwaysTheme.background.ignoresSafeArea()
        )
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Top header row (back arrow + title/date)

    private var topHeaderRow: some View {
        HStack(alignment: .center) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(HallwaysTheme.text)
                    .frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(collection.title.isEmpty ? "[untitled collection]" : collection.title)
                    .font(.specialElite(size: 16))
                    .foregroundColor(HallwaysTheme.text)
                    .lineLimit(1)
                Text(collection.lastEditedAt.hallwaysStamp)
                    .font(.printvetica(size: 12))
                    .foregroundColor(Color(hex: "9F9F9F"))
            }
        }
    }

    // MARK: - Media row

    private func mediaRow(cardHeight: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(collection.mediaPieces) { piece in
                    PieceCardView(
                        piece: piece,
                        tiltAngle: 0,
                        cardHeight: cardHeight,
                        cardWidth: nil
                    )
                    .matchedGeometryEffect(
                        id: piece.id,
                        in: heroNamespace,
                        isSource: selectedPiece?.id != piece.id
                    )
                    .zIndex(lastInteractedID == piece.id ? 100 : 0)
                    .onTapGesture {
                        lastInteractedID = piece.id
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedPiece = piece
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Text region

    // Root is a Color (zero intrinsic size) so the .frame(height:) applied by
    // the caller actually wins. Using an Image with .resizable().aspectRatio(.fill)
    // as the ZStack root made the parent ZStack adopt the image's HUGE natural
    // pixel size as its ideal, and SwiftUI's VStack then handed that ideal to
    // textRegion while starving mediaRow. Pushing the Image into .overlay()
    // keeps it as paint-only — overlays don't contribute to parent sizing.
    private var textRegion: some View {
        Color(hex: "E8E0C8")
            .overlay(
                Image("green-paper-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            )
            .overlay(
                ScrollView(.vertical, showsIndicators: false) {
                    Text(collection.textPiece?.textContent ?? "")
                        .font(.specialElite(size: 18))
                        .foregroundColor(HallwaysTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 32)
                }
            )
            .clipped()
    }

    // MARK: - Edit CTA + reveal gesture

    private var editCTA: some View {
        let domeTotal = editCTAHeight + editCTABottomCurve
        // Inner shape ignores top safe area, so when revealed the dome's paint
        // covers the status-bar zone (curve from screen top down). The "edit"
        // text lives in the outer ZStack (which respects safe area), so it sits
        // BELOW the status-bar items, centered visually on the black dome.
        //
        // Hidden offset = -(domeTotal + 100). The +100 buffer guarantees the
        // bottom of the curve clears the safe-area boundary even on tall
        // status-bar devices — prevents a sliver peeking at rest.
        let hiddenOffset: CGFloat = -(domeTotal + 100)
        let translateY: CGFloat = hiddenOffset * (1 - editRevealProgress)
        return ZStack(alignment: .top) {
            HalfMoonCTA(
                topCurveHeight: 0,
                bottomCurveHeight: editCTABottomCurve
            )
            .fill(HallwaysTheme.text)
            .frame(height: editCTAHeight)
            .ignoresSafeArea(edges: .top)

            Text("edit")
                .font(.specialElite(size: 16))
                .foregroundColor(.white)
                .padding(.top, 40)
        }
        .frame(height: editCTAHeight)
        .offset(y: translateY)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showEditOverview = true
                editRevealProgress = 0
            }
        }
    }

    private var revealDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                isDraggingReveal = true
                let dy = max(0, value.translation.height)
                editRevealProgress = min(1, dy / (revealThreshold * 2))
            }
            .onEnded { value in
                isDraggingReveal = false
                if value.translation.height > revealThreshold {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        editRevealProgress = 1
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        editRevealProgress = 0
                    }
                }
            }
    }

    private func collapseEditCTA() {
        withAnimation(.easeOut(duration: 0.2)) {
            editRevealProgress = 0
        }
    }

    // MARK: - Hero swipe binding

    private var viewerBinding: Binding<Piece?> {
        Binding(
            get: { selectedPiece },
            set: { newValue in
                selectedPiece = newValue
                if let id = newValue?.id {
                    lastInteractedID = id
                }
            }
        )
    }
}
