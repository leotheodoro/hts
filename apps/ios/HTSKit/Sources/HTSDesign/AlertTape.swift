import SwiftUI

/// Warning tape: `blood` and `black` stripes at `angle-tape` (-45°), used for the competition alert.
public struct AlertTape: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            let step = HTSSpacing.space7 / 2
            var x = -size.height
            while x < size.width + size.height {
                var stripe = Path()
                stripe.move(to: CGPoint(x: x, y: size.height))
                stripe.addLine(to: CGPoint(x: x + size.height, y: 0))
                stripe.addLine(to: CGPoint(x: x + size.height + step, y: 0))
                stripe.addLine(to: CGPoint(x: x + step, y: size.height))
                stripe.closeSubpath()
                context.fill(stripe, with: .color(Color.hts.blood))
                x += step * 2
            }
        }
        .background(Color.hts.black)
        .frame(height: HTSSpacing.space2)
        .accessibilityHidden(true)
    }
}
