import SwiftUI
import UIKit

struct ImageViewerView: View {
    let piece: Piece
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var anchor: UnitPoint = .center
    @State private var pinchOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black
                .opacity(bgOpacity)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            content
                .matchedGeometryEffect(id: piece.id, in: namespace, isSource: true)
                .scaleEffect(scale, anchor: anchor)
                .offset(
                    x: dragOffset.width + pinchOffset.width,
                    y: dragOffset.height + pinchOffset.height
                )
                .gesture(LivePinchGesture(
                    scale: $scale,
                    anchor: $anchor,
                    offset: $pinchOffset,
                    onEnded: resetZoom
                ))
                .simultaneousGesture(dragGesture)
        }
        .statusBarHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if piece.type == .media, let fileName = piece.imageFileName {
            Image(fileName)
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

    private var bgOpacity: Double {
        let distance = hypot(dragOffset.width, dragOffset.height)
        return 1.0 - min(1.0, Double(distance / 300))
    }

    private func resetZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = 1.0
            anchor = .center
            pinchOffset = .zero
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = CGSize(
                    width: max(0, value.translation.width),
                    height: max(0, value.translation.height)
                )
            }
            .onEnded { _ in
                let distance = hypot(dragOffset.width, dragOffset.height)
                if distance > 100 {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = .zero
                    }
                }
            }
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
