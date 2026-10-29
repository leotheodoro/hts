import HTSDesign
import SwiftUI

/// Common screen frame: the "HTS" mark on top (the only stencil in the app), the screen title, then content.
struct ScreenScaffold<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HTSSpacing.space7) {
                Text(verbatim: "HTS")
                    .htsTextStyle(.brandApp)
                    .foregroundStyle(Color.hts.bone)
                    .accessibilityLabel("Hard To Submit")
                    .accessibilityAddTraits(.isHeader)
                Text(title)
                    .htsTextStyle(.uiTitle)
                    .foregroundStyle(Color.hts.bone)
                    .accessibilityAddTraits(.isHeader)
                content
            }
            .padding(.horizontal, HTSSpacing.space5)
            .padding(.vertical, HTSSpacing.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.bottom, BrandTabBar.height, for: .scrollContent)
        .safeAreaInset(edge: .bottom, spacing: 0) { ActiveSessionBar() }
        .background(Color.hts.black)
        .foregroundStyle(Color.hts.bone)
    }
}

/// Example card used by the placeholder screens until each tab gets its ticket.
struct PlaceholderCard: View {
    let label: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                Text(label).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                Text(text).htsTextStyle(.body).foregroundStyle(Color.hts.bone)
            }
        }
    }
}
