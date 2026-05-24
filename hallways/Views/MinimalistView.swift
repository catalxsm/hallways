import SwiftUI
import SwiftData

struct MinimalistView: View {
    let collections: [Collection]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 72) {
                ForEach(collections) { collection in
                    NavigationLink(value: collection) {
                        CollectionRowView(collection: collection)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 16)
            .padding(.vertical, 40)
            .padding(.bottom, 60)
        }
    }
}
