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
        let fonts: [(name: String, ext: String)] = [
            ("SpecialElite-Regular", "ttf"),
            ("Printvetica", "otf"),
        ]
        for font in fonts {
            if let url = Bundle.main.url(forResource: font.name, withExtension: font.ext) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
