import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            FeedView()
                .background(HallwaysTheme.background)

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // Brief settle (OS launch screen already covered cold-start time).
            try? await Task.sleep(for: .seconds(0.3))

            withAnimation(.easeOut(duration: 0.35)) {
                showSplash = false
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Piece.self, Collection.self], inMemory: true)
}
