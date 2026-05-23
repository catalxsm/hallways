import SwiftUI
import SwiftData
import CoreText

@main
struct hallwaysApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Piece.self,
            Collection.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    SampleDataProvider.seed(
                        modelContext: sharedModelContainer.mainContext
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func registerCustomFonts() {
        if let fontURL = Bundle.main.url(forResource: "SpecialElite-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }
}
