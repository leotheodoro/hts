import HTSDesign
import SwiftUI

/// Common screen frame: the HARD TO SUBMIT wordmark with the 不屈 seal on top (the only stencil in the app), the
/// screen title, then content.
struct ScreenScaffold<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content
    @Environment(\.scrollToTopSignal) private var scrollToTopSignal
    @Environment(AppModel.self) private var app
    @Namespace private var top

    var body: some View {
        ScrollViewReader { proxy in
            scroll.onChange(of: scrollToTopSignal) {
                withAnimation { proxy.scrollTo(top, anchor: .top) }
            }
        }
    }

    private var scroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HTSSpacing.space7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Wordmark.text)
                        .htsTextStyle(.brandApp)
                        .accessibilityLabel("Hard To Submit")
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if case .offline = app.health {
                        APIDownBadge()
                    } else {
                        Text(verbatim: "不屈")
                            .font(
                                .custom(
                                    HTSFontFamily.kanji.postScriptName(weight: 900), size: HTSTextStyle.brandApp.size)
                            )
                            .foregroundStyle(Color.hts.tabIdle)
                            .accessibilityHidden(true)
                    }
                }
                .id(top)
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

extension EnvironmentValues {
    /// Changes when the selected tab is tapped again on its first page (#106).
    @Entry var scrollToTopSignal = 0
}

extension View {
    func scrollToTopSignal(_ value: Int?) -> some View {
        environment(\.scrollToTopSignal, value ?? 0)
    }
}

/// Pushed page: a back button instead of the brand and the screen title.
struct DetailScaffold<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HTSSpacing.space7) {
                Button {
                    dismiss()
                } label: {
                    Label("Voltar", systemImage: "chevron.left").htsTextStyle(.bodyStrong).frame(minHeight: 44)
                }
                .foregroundStyle(Color.hts.bone)
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

/// Takes the place of the 不屈 seal while the API does not answer /health (#139). Red is an alert here.
struct APIDownBadge: View {
    var body: some View {
        Text("API FORA DO AR")
            .htsTextStyle(.label)
            .foregroundStyle(Color.hts.onBlood)
            .padding(.horizontal, HTSSpacing.space2)
            .padding(.vertical, HTSSpacing.space1)
            .background(Color.hts.blood)
            .accessibilityLabel("A API está fora do ar. Os dados ficam no aparelho.")
    }
}

/// HARD TO in `bone`, SUBMIT in `blood` (#87). The stencil appears only in this wordmark.
enum Wordmark {
    static var text: AttributedString {
        var hard = AttributedString("HARD TO ")
        hard.foregroundColor = Color.hts.bone
        var submit = AttributedString("SUBMIT")
        submit.foregroundColor = Color.hts.blood
        return hard + submit
    }
}
