import SwiftUI

// A rectangle whose top and bottom edges can each be an outward-bulging arc.
// topCurveHeight bulges the top edge UP above the rect; bottomCurveHeight
// bulges the bottom edge DOWN below it. Both halves animate via AnimatablePair.
//
// bottom dome (publish/save footer): topCurveHeight > 0, bottomCurveHeight = 0
// top dome (edit CTA pulled down):   topCurveHeight = 0, bottomCurveHeight > 0
// publish exit curtain:              topCurveHeight = 0, bottomCurveHeight > 0
struct HalfMoonCTA: Shape {
    var topCurveHeight: CGFloat
    var bottomCurveHeight: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCurveHeight, bottomCurveHeight) }
        set {
            topCurveHeight = newValue.first
            bottomCurveHeight = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        // Control points OUTSIDE the rect — bulge the edges away from center
        // so the shape reads as a dome rising up (top) or hanging down (bottom).
        let topMid = CGPoint(x: rect.midX, y: rect.minY - topCurveHeight)
        let bottomMid = CGPoint(x: rect.midX, y: rect.maxY + bottomCurveHeight)

        p.move(to: topLeft)
        if topCurveHeight > 0 {
            p.addQuadCurve(to: topRight, control: topMid)
        } else {
            p.addLine(to: topRight)
        }
        p.addLine(to: bottomRight)
        if bottomCurveHeight > 0 {
            p.addQuadCurve(to: bottomLeft, control: bottomMid)
        } else {
            p.addLine(to: bottomLeft)
        }
        p.closeSubpath()
        return p
    }
}
