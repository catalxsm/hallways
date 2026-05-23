import SwiftUI

struct ContentView: View {
    var body: some View {
        FeedView()
            .background(HallwaysTheme.background)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Piece.self, Collection.self], inMemory: true)
}
