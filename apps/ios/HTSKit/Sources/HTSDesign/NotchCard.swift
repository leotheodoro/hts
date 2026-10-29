import SwiftUI

/// Surface card with the notch and a hairline border. No shadow, no gradient.
public struct NotchCard<Content: View>: View {
    private let cut: CGFloat
    private let border: Color
    private let content: Content

    /// `border` is `line`; `blood` marks the one card that is the focus (the current arc).
    public init(cut: CGFloat = HTSNotch.lg, border: Color = Color.hts.line, @ViewBuilder content: () -> Content) {
        self.cut = cut
        self.border = border
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HTSSpacing.space5)
            .background(Color.hts.surface, in: NotchShape(cut: cut))
            .overlay(NotchShape(cut: cut).strokeBorder(border, lineWidth: HTSStroke.hair))
    }
}
