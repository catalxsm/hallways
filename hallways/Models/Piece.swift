import Foundation
import SwiftData

enum PieceType: String, Codable {
    case text
    case media
}

@Model
final class Piece {
    var id: UUID
    var type: PieceType
    var textContent: String?
    var imageFileName: String?
    var imageData: Data?
    var sortOrder: Int
    var createdAt: Date
    var collection: Collection?

    var tilt: Double {
        let hash = id.hashValue
        let normalized = Double(abs(hash) % 601) / 100.0 // 0...6
        return normalized - 3.0 // -3...3
    }

    init(
        type: PieceType,
        textContent: String? = nil,
        imageFileName: String? = nil,
        imageData: Data? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.type = type
        self.textContent = textContent
        self.imageFileName = imageFileName
        self.imageData = imageData
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
