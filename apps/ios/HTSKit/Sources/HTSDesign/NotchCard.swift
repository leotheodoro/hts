import SwiftUI

/// Surface card with the notch and a hairline border. No shadow, no gradient.
public struct NotchCard<Content: View>: View {
    private let cut: CGFloat
    private let content: Content

    public init(cut: CGFloat = HTSNotch.lg, @ViewBuilder content: () -> Content) {
        self.cut = cut
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HTSSpacing.space5)
            .background(Color.hts.surface, in: NotchShape(cut: cut))
            .overlay(NotchShape(cut: cut).strokeBorder(Color.hts.line, lineWidth: HTSStroke.hair))
    }
}
