import SwiftUI

struct HallwaysTheme {
    // MARK: - Colors
    static let background = Color(hex: "FCFCFC")
    static let text = Color(hex: "121212")
    static let overlay = Color(hex: "7A7A7A")
    static let card = Color(hex: "EFEFEF")

    // MARK: - Opacity
    static let overlayOpacity: Double = 0.70
    static let cardOpacity: Double = 0.80

    // MARK: - Layout
    static let tiltRange: ClosedRange<Double> = -3...3
    static let overlapOffset: CGFloat = -20
    static let gridSpacing: CGFloat = 16
    static let expandedCardCornerRadius: CGFloat = 20
    static let pieceCardHeight: CGFloat = 200
    static let minimalistRowHeight: CGFloat = 210
    static let collectionRowHeight: CGFloat = 210
    static let fileGridItemHeight: CGFloat = 150
    static let stackPreviewSize: CGFloat = 80
}

// MARK: - Font Helper

extension Font {
    static func specialElite(size: CGFloat) -> Font {
        .custom("SpecialElite-Regular", size: size)
    }
}

// MARK: - Color Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
