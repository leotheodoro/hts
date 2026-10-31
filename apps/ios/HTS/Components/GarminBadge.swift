import HTSDesign
import SwiftUI

/// Marks what came from Garmin. The word only, in Garmin's blue, until the official brand kit arrives with the
/// approved access (#168).
struct GarminBadge: View {
    var body: some View {
        Text(verbatim: "GARMIN")
            .htsTextStyle(.label)
            .foregroundStyle(Color.hts.onGarmin)
            .padding(.horizontal, HTSSpacing.space2)
            .padding(.vertical, HTSSpacing.space1)
            .background(Color.hts.garmin)
            .accessibilityLabel(Text("Veio do Garmin"))
    }
}
