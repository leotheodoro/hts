import SwiftUI

public enum HTSButtonKind: Sendable {
    /// Main action: `blood` fill, `on-blood` label, `notch-sm`. One per screen.
    case primary
    /// Secondary action: `line-strong` border, `bone` label.
    case ghost
}

public struct HTSButtonStyle: ButtonStyle {
    public var kind: HTSButtonKind

    public init(_ kind: HTSButtonKind) {
        self.kind = kind
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = NotchShape(cut: HTSNotch.sm)
        configuration.label
            .htsTextStyle(.bodyStrong)
            .foregroundStyle(kind == .primary ? Color.hts.onBlood : Color.hts.bone)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, HTSSpacing.space5)
            .background {
                if kind == .primary { shape.fill(Color.hts.blood) }
            }
            .overlay {
                if kind == .ghost { shape.strokeBorder(Color.hts.lineStrong, lineWidth: HTSStroke.hair) }
            }
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Brand button. Labels start with a verb: "Iniciar treino", "Ver treino".
public struct HTSButton: View {
    private let title: LocalizedStringKey
    private let kind: HTSButtonKind
    private let action: () -> Void

    public init(_ title: LocalizedStringKey, kind: HTSButtonKind = .primary, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.action = action
    }

    public var body: some View {
        Button(title, action: action).buttonStyle(HTSButtonStyle(kind))
    }
}
