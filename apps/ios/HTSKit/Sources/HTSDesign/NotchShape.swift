import SwiftUI

/// The brand notch: top-left and bottom-right corners cut at 45°. Every other corner is square.
public struct NotchShape: InsettableShape {
    public var cut: CGFloat
    var inset: CGFloat = 0

    public init(cut: CGFloat = HTSNotch.lg) {
        self.cut = cut
    }

    public func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        // Insetting a 45° cut moves it inwards by inset × (√2 − 1) along each edge.
        let c = max(0, min(cut - inset * (2.squareRoot() - 1), r.width / 2, r.height / 2))
        var path = Path()
        path.move(to: CGPoint(x: r.minX + c, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        path.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        path.closeSubpath()
        return path
    }

    public func inset(by amount: CGFloat) -> NotchShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}
