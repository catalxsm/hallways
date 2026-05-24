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
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.5)) {
                showSplash = false
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Piece.self, Collection.self], inMemory: true)
}
