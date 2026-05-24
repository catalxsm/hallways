import SwiftUI
import UIKit

struct ContentView: View {
    @State private var showSplash = true
    @State private var showCurtain = true
    @State private var curtainYOffset: CGFloat = 0

    private let curtainCurveHeight: CGFloat = 80

    var body: some View {
        ZStack(alignment: .top) {
            FeedView()
                .background(HallwaysTheme.background)
                // Suppress any implicit animations on the underlying FeedView
                // while the curtain is still up — without this, the feed
                // visibly settles into its layout right as the curtain
                // finishes, which reads as a snap.
                .transaction { transaction in
                    if showCurtain { transaction.animation = nil }
                }

            // White semicircle curtain — sits underneath the splash so that
            // when the splash fades, the curtain is already covering the
            // feed. Then it slides downward off the screen, with the
            // upward-curving dome as its trailing edge.
            if showCurtain {
                PublishSemicircleShape(
                    topCurveHeight: curtainCurveHeight,
                    bottomCurveHeight: 0
                )
                .fill(HallwaysTheme.background)
                .frame(height: 1500)
                .offset(y: curtainYOffset)
                .ignoresSafeArea()
                .zIndex(1)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .task {
            // Brief settle (OS launch screen already covered cold-start time).
            try? await Task.sleep(for: .seconds(0.3))

            // Fade the splash AND slide the curtain at the same time — the
            // splash and curtain are both white so the fade is visually free;
            // no reason to pause between them.
            let screenH = UIScreen.main.bounds.height
            withAnimation(.easeOut(duration: 0.2)) {
                showSplash = false
            }
            withAnimation(.easeInOut(duration: 0.4)) {
                curtainYOffset = screenH + 200
            }
            try? await Task.sleep(for: .seconds(0.42))

            showCurtain = false
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Piece.self, Collection.self], inMemory: true)
}
