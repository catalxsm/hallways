import Foundation
import SwiftData

@Model
final class Collection {
    var id: UUID
    var title: String
    @Relationship(deleteRule: .cascade, inverse: \Piece.collection)
    var pieces: [Piece]
    var lastEditedAt: Date
    var sortOrder: Int

    var orderedPieces: [Piece] {
        pieces.sorted { $0.sortOrder < $1.sortOrder }
    }

    init(
        title: String,
        pieces: [Piece] = [],
        lastEditedAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.pieces = pieces
        self.lastEditedAt = lastEditedAt
        self.sortOrder = sortOrder
    }
}
