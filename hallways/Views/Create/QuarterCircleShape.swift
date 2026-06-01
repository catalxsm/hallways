import SwiftUI

// A pie slice anchored at the top-left corner of its rect, curving outward to
// the bottom-right. Used as the backdrop for the X cancel button in the
// writing editor.
struct QuarterCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let corner = CGPoint(x: rect.minX, y: rect.minY)
        let radius = min(rect.width, rect.height)
        p.move(to: corner)
        p.addLine(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        p.addArc(
            center: corner,
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        p.closeSubpath()
        return p
    }
}
