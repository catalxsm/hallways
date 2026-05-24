import SwiftUI
import UIKit

struct ImageViewerView: View {
    let pieces: [Piece]
    @Binding var selectedPiece: Piece?
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var anchor: UnitPoint = .center
    @State private var pinchOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            TabView(selection: pageSelection) {
                ForEach(pieces) { piece in
                    page(for: piece)
                        .tag(Optional(piece.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .statusBarHidden(true)
        // Swipe-down to dismiss. simultaneousGesture + onEnded-only means
        // TabView's horizontal swipe still wins for horizontal drags; this
        // only triggers when the gesture ends with a decisively-vertical-down
        // translation, so it doesn't fight paging.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if dy > 80 && dy > abs(dx) * 2 {
                        onDismiss()
                    }
                }
        )
        .onChange(of: selectedPiece?.id) { _, _ in
            resetZoom()
        }
    }

    // Wraps selectedPiece as a UUID? binding for TabView's selection.
    private var pageSelection: Binding<UUID?> {
        Binding(
            get: { selectedPiece?.id },
            set: { newID in
                selectedPiece = pieces.first(where: { $0.id == newID })
            }
        )
    }

    @ViewBuilder
    private func page(for piece: Piece) -> some View {
        let isCurrent = selectedPiece?.id == piece.id
        ZStack {
            Color.clear
            if isCurrent {
                // Only the active page owns the matched geometry — off-screen
                // pages would otherwise try to match their LazyVStack source
                // card's geometry and cause the scatter glitch during paging.
                content(for: piece)
                    .matchedGeometryEffect(
                        id: piece.id,
                        in: namespace,
                        isSource: true
                    )
                    .scaleEffect(scale, anchor: anchor)
                    .offset(
                        x: pinchOffset.width,
                        y: pinchOffset.height
                    )
                    .gesture(LivePinchGesture(
                        scale: $scale,
                        anchor: $anchor,
                        offset: $pinchOffset,
                        onEnded: resetPinch
                    ))
            } else {
                content(for: piece)
            }
        }
    }

    @ViewBuilder
    private func content(for piece: Piece) -> some View {
        if piece.type == .media, let fileName = piece.imageFileName {
            let resolved: Image = {
                if let ui = ImageStorage.loadImage(named: fileName) {
                    return Image(uiImage: ui)
                }
                return Image(fileName)
            }()
            resolved
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if piece.type == .text, let text = piece.textContent {
            ZStack {
                Color(hex: "F5F0E8")
                ScrollView(.vertical, showsIndicators: false) {
                    Text(text)
                        .font(.specialElite(size: 18))
                        .foregroundColor(HallwaysTheme.text)
                        .multilineTextAlignment(.leading)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .padding(.horizontal, 24)
        }
    }

    private func resetPinch() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = 1.0
            anchor = .center
            pinchOffset = .zero
        }
    }

    private func resetZoom() {
        scale = 1.0
        anchor = .center
        pinchOffset = .zero
    }
}

private struct LivePinchGesture: UIGestureRecognizerRepresentable {
    @Binding var scale: CGFloat
    @Binding var anchor: UnitPoint
    @Binding var offset: CGSize
    var onEnded: () -> Void

    final class Coordinator {
        var startLocation: CGPoint?
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        UIPinchGestureRecognizer()
    }

    func updateUIGestureRecognizer(_ recognizer: UIPinchGestureRecognizer, context: Context) {}

    func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        guard let view = recognizer.view else { return }
        let bounds = view.bounds

        switch recognizer.state {
        case .began:
            let loc = recognizer.location(in: view)
            context.coordinator.startLocation = loc
            anchor = UnitPoint(
                x: bounds.width > 0 ? loc.x / bounds.width : 0.5,
                y: bounds.height > 0 ? loc.y / bounds.height : 0.5
            )
            offset = .zero
            scale = min(max(recognizer.scale, 1.0), 4.0)

        case .changed:
            guard let start = context.coordinator.startLocation else { return }
            let loc = recognizer.location(in: view)
            scale = min(max(recognizer.scale, 1.0), 4.0)
            offset = CGSize(width: loc.x - start.x, height: loc.y - start.y)

        case .ended, .cancelled, .failed:
            context.coordinator.startLocation = nil
            onEnded()

        default:
            break
        }
    }
}
