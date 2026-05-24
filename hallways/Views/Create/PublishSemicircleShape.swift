import SwiftUI

// A rectangle whose top and bottom edges can each be an inward-curving arc.
// topCurveHeight controls how much the top edge bulges DOWN into the shape;
// bottomCurveHeight controls how much the bottom edge bulges UP into the shape.
//
// publish footer state:  topCurveHeight > 0, bottomCurveHeight = 0   (curve facing up)
// publish exit state:    topCurveHeight = 0, bottomCurveHeight > 0   (flipped, curve facing down)
struct PublishSemicircleShape: Shape {
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
