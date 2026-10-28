import SwiftUI

/// Palette, type and base components on one screen. Used by the SwiftUI preview and the Debug diagnostics.
public struct DesignCatalog: View {
    public init() {
        HTSFonts.register()
    }

    private let swatches: [(String, Color)] = [
        ("black", .hts.black), ("charcoal", .hts.charcoal), ("surface", .hts.surface), ("line", .hts.line),
        ("line-strong", .hts.lineStrong), ("track", .hts.track), ("bone", .hts.bone), ("grey", .hts.grey),
        ("grey-app", .hts.greyApp), ("tab-idle", .hts.tabIdle), ("blood", .hts.blood),
        ("blood-deep", .hts.bloodDeep), ("red-text", .hts.redText), ("olive", .hts.olive),
        ("olive-ink", .hts.oliveInk), ("khaki", .hts.khaki), ("rank-fill", .hts.rankFill), ("tag", .hts.tag),
        ("tag-edge", .hts.tagEdge), ("tag-ink", .hts.tagInk),
    ]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HTSSpacing.space7) {
                section("PALETA") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 72), spacing: HTSSpacing.space3)],
                        spacing: HTSSpacing.space3
                    ) {
                        ForEach(swatches, id: \.0) { name, color in
                            VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                                Rectangle().fill(color).frame(height: 44)
                                    .overlay(Rectangle().strokeBorder(Color.hts.line, lineWidth: HTSStroke.hair))
                                Text(verbatim: name).htsTextStyle(.dataSm).foregroundStyle(Color.hts.greyApp)
                            }
                        }
                    }
                }
                section("TIPOGRAFIA") {
                    ForEach(HTSTextStyle.all, id: \.name) { style in
                        VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                            Text(verbatim: sample(for: style)).htsTextStyle(style).foregroundStyle(Color.hts.bone)
                                .lineLimit(1).minimumScaleFactor(0.3)
                            Text(verbatim: style.name).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        }
                    }
                }
                section("COMPONENTES") {
                    NotchCard {
                        VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                            Text(verbatim: "PRÓXIMO TREINO · 05/06").htsTextStyle(.label)
                                .foregroundStyle(Color.hts.grey)
                            Text(verbatim: "B · Trincheira").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
                            Text(verbatim: "062.5 KG × 06 · 01:30").htsTextStyle(.data)
                                .foregroundStyle(Color.hts.bone)
                        }
                    }
                    HTSButton("Iniciar treino") {}
                    HTSButton("Ver treino", kind: .ghost) {}
                }
            }
            .padding(HTSSpacing.space5)
        }
        .background(Color.hts.black)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space4) {
            Text(verbatim: title).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            content()
        }
    }

    private func sample(for style: HTSTextStyle) -> String {
        switch style {
        case .brandHero, .brandStack: "HARD TO SUBMIT"
        case .brandApp: "HTS"
        case .pieceTitle: "LINHA DE FRENTE"
        case .pieceSub: "B · TRINCHEIRA"
        case .uiDisplay: "1:12"
        case .uiTitle: "B · Trincheira"
        case .uiSection: "Zercher Squat"
        case .data: "062.5 KG × 06"
        case .dataSm: "27.10.26 · TR 13"
        case .label: "PRÓXIMO TREINO · 05/06"
        case .kanji: "不屈"
        default: "Ativação e Core concluídos · 12 séries"
        }
    }
}

#Preview("Design system") {
    DesignCatalog()
        .preferredColorScheme(.dark)
}
