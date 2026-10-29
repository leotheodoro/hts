import HTSDesign
import HTSDomain
import SwiftUI

/// Attribute abbreviations of a block (FOR, EXP, GÁS, COR, MOB) as olive tags, so they read apart from the block
/// name (#96).
struct AttributeBadges: View {
    let attributes: [Attribute]

    var body: some View {
        HStack(spacing: HTSSpacing.space1) {
            ForEach(attributes, id: \.self) { attribute in
                Text(verbatim: attribute.abbreviation)
                    .htsTextStyle(.label)
                    .foregroundStyle(Color.hts.oliveInk)
                    .padding(.horizontal, HTSSpacing.space2)
                    .padding(.vertical, HTSSpacing.space1)
                    .background(Color.hts.olive)
                    .accessibilityLabel(Text(attribute.label))
            }
        }
    }
}
