import SwiftUI

/// First-launch splash: the pre-composed cluster image, full width.
/// Shown over the feed on launch, then faded out by ContentView.
struct SplashView: View {
    var body: some View {
        ZStack {
            HallwaysTheme.background

            Image("splash-screen-img")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SplashView()
}
