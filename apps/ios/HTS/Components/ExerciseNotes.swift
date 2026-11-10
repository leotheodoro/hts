import HTSDesign
import SwiftUI

/// Observações of a prescribed exercise (#212), under its prescription: a hairline on the left, the coach's words
/// in `bone`.
struct ExerciseNotes: View {
    let text: String

    var body: some View {
        Text(verbatim: text).htsTextStyle(.caption).foregroundStyle(Color.hts.bone)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, HTSSpacing.space2)
            .overlay(alignment: .leading) {
                Rectangle().fill(Color.hts.line).frame(width: HTSStroke.hair)
            }
            .accessibilityLabel(Text("Observações: \(text)"))
    }
}
