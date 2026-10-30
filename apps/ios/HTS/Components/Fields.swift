import HTSDesign
import HTSDomain
import SwiftUI
import UIKit

/// Mono caps label above a form control.
struct FieldLabel: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
    }
}

/// Text field on `surface` with a hairline border. Square corners, 52 pt tall for one-hand use.
struct HTSTextField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var prompt: LocalizedStringKey = ""
    /// Hides the text (password) and lets iOS offer saved passwords.
    var secure = false
    var contentType: UITextContentType?

    var body: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space2) {
            FieldLabel(text: label)
            Group {
                if secure {
                    SecureField(text: $text, prompt: Text(prompt).foregroundStyle(Color.hts.tabIdle)) { Text(label) }
                } else {
                    TextField(text: $text, prompt: Text(prompt).foregroundStyle(Color.hts.tabIdle)) { Text(label) }
                }
            }
            .textContentType(contentType)
            .htsTextStyle(.body)
            .foregroundStyle(Color.hts.bone)
            .padding(.horizontal, HTSSpacing.space4)
            .frame(minHeight: 52)
            .background(Color.hts.surface)
            .overlay(Rectangle().strokeBorder(Color.hts.line, lineWidth: HTSStroke.hair))
        }
    }
}

/// Thin progress bar: `track` rail with a `bone` fill, or `blood` when highlighted.
struct ProgressBar: View {
    let value: Double
    var highlighted = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.hts.track)
                Rectangle().fill(highlighted ? Color.hts.blood : Color.hts.bone)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: HTSStroke.rule)
        .accessibilityElement()
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

extension LocalDate {
    /// "02.11.26", as in the design system data samples.
    var short: String {
        String(format: "%02d.%02d.%02d", day, month, year % 100)
    }

    var date: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    static var today: LocalDate { LocalDate(.now, in: .current) }
}
