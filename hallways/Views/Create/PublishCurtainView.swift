import SwiftUI
import UIKit

// Owns the rise → hold → exit animation for the publish curtain.
// Reports milestones via two closures:
//   onRiseComplete — fired when the curtain has fully covered the screen.
//                    Parent should insert the new Collection now and dismiss
//                    the CreateEditView, so the feed (with the new post) is
//                    visible underneath the curtain during exit.
//   onComplete    — fired when the curtain has fully exited off the top.
//                    Parent should remove this overlay.
struct PublishCurtainView: View {
    var label: String = "publish"
    var onRiseComplete: () -> Void
    var onComplete: () -> Void

    @State private var height: CGFloat = 90
    @State private var topCurve: CGFloat = 56
    @State private var bottomCurve: CGFloat = 0
    @State private var yOffset: CGFloat = 0
    @State private var labelOpacity: Double = 1
    @State private var didStart: Bool = false

    private let startHeight: CGFloat = 90
    private let startTopCurve: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.clear

                ZStack(alignment: .top) {
                    HalfMoonCTA(
                        topCurveHeight: topCurve,
                        bottomCurveHeight: bottomCurve
                    )
                    .fill(HallwaysTheme.text)
                    .frame(height: height)

                    Text(label)
                        .font(.specialElite(size: 16))
                        .foregroundColor(.white)
                        .opacity(labelOpacity)
                        .padding(.top, 24)
                }
                .offset(y: yOffset)
            }
            .ignoresSafeArea()
            .onAppear {
                guard !didStart else { return }
                didStart = true
                // Use full screen height instead of the safe-area-constrained
                // geometry — otherwise a keyboard-shrunk reader makes the curtain
                // too short to cover the whole screen.
                let fullHeight = max(geo.size.height, UIScreen.main.bounds.height)
                runAnimation(screenHeight: fullHeight)
            }
        }
    }

    private func runAnimation(screenHeight: CGFloat) {
        // Phase 1: rise — grow to cover full screen, flatten top curve, fade label.
        withAnimation(.easeInOut(duration: 0.55)) {
            height = screenHeight + 240
            topCurve = 0
            labelOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            onRiseComplete()

            // Phase 2: hold — brief pause while parent updates feed underneath.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Phase 3: exit — slide up off-screen, flip curve to bottom-facing.
                withAnimation(.easeInOut(duration: 0.6)) {
                    yOffset = -(screenHeight + 280)
                    bottomCurve = 60
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    onComplete()
                }
            }
        }
    }
}
