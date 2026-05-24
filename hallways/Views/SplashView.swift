import SwiftUI

/// First-launch splash: the pre-composed cluster image above the
/// "means a lot you're here" wordmark. Shown over the feed on launch,
/// then faded out by ContentView.
struct SplashView: View {
    var body: some View {
        ZStack {
            HallwaysTheme.background
                .ignoresSafeArea()

            VStack(spacing: 56) {
                Image("splash-screen-img")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 24)

                Text("means a lot you're here")
                    .font(.specialElite(size: 16))
                    .foregroundColor(HallwaysTheme.text)
            }
        }
    }
}

#Preview {
    SplashView()
}
