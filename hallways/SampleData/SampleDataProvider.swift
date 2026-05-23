import Foundation
import SwiftData
import UIKit

struct SampleDataProvider {
    static func seed(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Piece>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        // Standalone piece 1: portrait
        let portrait = Piece(
            type: .media,
            imageFileName: "seattle-camera-portrait",
            sortOrder: 0
        )
        modelContext.insert(portrait)

        // Standalone piece 2: selfie
        let selfie = Piece(
            type: .media,
            imageFileName: "selfie-retro-cam",
            sortOrder: 1
        )
        modelContext.insert(selfie)

        // Collection: "outdoor life"
        let outdoorEyes = Piece(type: .media, imageFileName: "eyes-at-the-beach", sortOrder: 0)
        let outdoorPark = Piece(type: .media, imageFileName: "park-w-friends", sortOrder: 1)
        let outdoorWater = Piece(type: .media, imageFileName: "water-in-guatamala", sortOrder: 2)

        let outdoorLife = Collection(
            title: "outdoor life",
            pieces: [outdoorEyes, outdoorPark, outdoorWater],
            lastEditedAt: dateFrom(month: 10, day: 29, year: 2025),
            sortOrder: 0
        )
        modelContext.insert(outdoorLife)

        // Collection: "inner child"
        let innerText = Piece(
            type: .text,
            textContent: """
            revive inner child:
            - play tag on a playground
            - color or paint for the \
            sheer joy of it
            - have ice cream for \
            dinner
            - try new things, learn a \
            new skill
            - go down a water slide
            - watch cartoons on the \
            weekend
            - play dress with a dog
            """,
            sortOrder: 0
        )
        let innerModeling = Piece(type: .media, imageFileName: "modeling", sortOrder: 1)
        let innerAshtray = Piece(type: .media, imageFileName: "ashtray-crashout", sortOrder: 2)

        let innerChild = Collection(
            title: "inner child",
            pieces: [innerText, innerModeling, innerAshtray],
            lastEditedAt: dateFrom(month: 10, day: 29, year: 2025),
            sortOrder: 1
        )
        modelContext.insert(innerChild)

        try? modelContext.save()
    }

    private static func dateFrom(month: Int, day: Int, year: Int) -> Date {
        var components = DateComponents()
        components.month = month
        components.day = day
        components.year = year
        return Calendar.current.date(from: components) ?? Date()
    }
}
