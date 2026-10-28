import SwiftUI

extension Font {
    /// Font for a token text style. Digits are always tabular.
    public static func hts(_ style: HTSTextStyle) -> Font {
        .custom(style.family.postScriptName(weight: style.weight), size: style.size).monospacedDigit()
    }
}

extension View {
    /// Applies the full text style: font, tracking, line height and caps.
    public func htsTextStyle(_ style: HTSTextStyle) -> some View {
        font(.hts(style))
            .tracking(style.tracking)
            .lineHeight(.exact(points: style.lineHeight))
            .textCase(style.uppercase ? .uppercase : nil)
    }
}
