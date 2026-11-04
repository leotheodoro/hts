import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// Progresso (#195), opened from the athlete card on the Home: where the athlete is, the ranks up to S and the
/// attributes against 30 days ago (layout "Escada" with the radar at the end).
struct ProgressScreen: View {
    @Environment(AppModel.self) private var app
    @State private var model: ProgressModel?

    var body: some View {
        DetailScaffold {
            Text("Progresso").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
            if let athlete = app.athlete, let model {
                currentCard(athlete, model)
                section("PATENTES") { ladderCard(model) }
                section("ATRIBUTOS · ÚLTIMOS 30 DIAS") { attributesCard(model) }
                radarCard(model)
            }
        }
        .task(id: "\(app.athlete?.id.uuidString ?? "")-\(app.dataVersion)") {
            guard let database = app.database, let athlete = app.athlete else { return }
            let model = self.model ?? ProgressModel(database: database, athleteId: athlete.id)
            await model.load()
            self.model = model
        }
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space2) {
            Text(title).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            content()
        }
    }

    private func currentCard(_ athlete: Athlete, _ model: ProgressModel) -> some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                HStack(spacing: HTSSpacing.space4) {
                    if let rank = model.history?.rank { RankBadge(rank: rank) }
                    VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                        Text(verbatim: athlete.displayName).htsTextStyle(.uiSection)
                        if let history = model.history {
                            Text(verbatim: "\(history.rank.name.uppercased()) · NÍVEL \(history.level)")
                                .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        }
                    }
                }
                if let level = model.levelProgress, let history = model.history {
                    VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                        ProgressBar(value: level.fraction, highlighted: true).frame(height: HTSStroke.bar)
                        HStack {
                            Text("XP").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                            Spacer()
                            Text(verbatim: "\(history.totalXp) / \(level.end)").htsTextStyle(.dataSm)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private func ladderCard(_ model: ProgressModel) -> some View {
        NotchCard {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.ladder.enumerated()), id: \.element.id) { index, step in
                    if index > 0 { Rectangle().fill(Color.hts.track).frame(height: HTSStroke.hair) }
                    ladderRow(step).padding(.vertical, HTSSpacing.space2)
                }
            }
        }
    }

    private func ladderRow(_ step: ProgressModel.Step) -> some View {
        HStack(spacing: HTSSpacing.space3) {
            RankBadge(rank: step.rank, compact: true)
            VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                Text(verbatim: step.rank.name).htsTextStyle(.bodyStrong)
                if let note = note(step) {
                    Text(note).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                }
            }
            Spacer()
            Text(verbatim: "NÍVEL \(step.rank.minLevel)").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                .monospacedDigit()
        }
        .opacity(step.state == .locked ? HTSOpacity.locked : 1)
        .accessibilityElement(children: .combine)
    }

    private func note(_ step: ProgressModel.Step) -> LocalizedStringKey? {
        let top = step.rank.id == .s
        switch step.state {
        case .current: return top ? "Você chegou ao topo" : "Você está aqui"
        case .next(let missing): return "Faltam \(missing) XP"
        case .reached: return "Alcançada"
        case .locked: return top ? "O topo" : nil
        }
    }

    private func attributesCard(_ model: ProgressModel) -> some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                ForEach(model.attributes) { row in
                    HStack(spacing: HTSSpacing.space3) {
                        Text(verbatim: row.attribute.abbreviation).htsTextStyle(.label)
                            .frame(width: 40, alignment: .leading)
                        ProgressBar(value: row.fraction)
                        Text(verbatim: "\(row.level)").htsTextStyle(.dataSm).monospacedDigit()
                            .frame(width: 28, alignment: .trailing)
                        Text(verbatim: row.change > 0 ? "+\(row.change)" : "=").htsTextStyle(.dataSm)
                            .monospacedDigit()
                            .foregroundStyle(row.change > 0 ? Color.hts.bone : Color.hts.greyApp)
                            .frame(width: 32, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(row.attribute.label))
                    .accessibilityValue(Text("Nível \(row.level), \(row.change) a mais em 30 dias"))
                }
            }
        }
    }

    private func radarCard(_ model: ProgressModel) -> some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Text("AGORA E HÁ 30 DIAS").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                AttributeRadar(rows: model.attributes).frame(height: 220)
                HStack(spacing: HTSSpacing.space4) {
                    Text("— Agora").foregroundStyle(Color.hts.khaki)
                    Text("- - Há 30 dias").foregroundStyle(Color.hts.greyApp)
                }
                .htsTextStyle(.label)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Five axes (FOR at the top, then clockwise), each level over the highest level shown; the shape 30 days ago is
/// dashed under the current one.
struct AttributeRadar: View {
    let rows: [ProgressModel.AttributeRow]

    var body: some View {
        let scale = Double(max(rows.map(\.level).max() ?? 1, rows.map(\.levelBefore).max() ?? 1, 5))
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2 + HTSSpacing.space2)
            let radius = min(proxy.size.width, proxy.size.height) / 2 - HTSSpacing.space6
            ZStack {
                ForEach([0.5, 1.0], id: \.self) { ring in
                    polygon(rows.map { _ in ring }, center, radius).stroke(Color.hts.track, lineWidth: HTSStroke.hair)
                }
                polygon(rows.map { Double($0.levelBefore) / scale }, center, radius)
                    .stroke(
                        Color.hts.greyApp,
                        style: StrokeStyle(lineWidth: HTSStroke.hair, dash: [HTSSpacing.space1, HTSSpacing.space1]))
                polygon(rows.map { Double($0.level) / scale }, center, radius)
                    .fill(Color.hts.khaki.opacity(HTSOpacity.radar))
                polygon(rows.map { Double($0.level) / scale }, center, radius)
                    .stroke(Color.hts.khaki, lineWidth: HTSStroke.hair)
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    Text(verbatim: row.attribute.abbreviation).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        .position(Self.point(index, count: rows.count, value: 1, center, radius + HTSSpacing.space4))
                }
            }
        }
    }

    private func polygon(_ values: [Double], _ center: CGPoint, _ radius: CGFloat) -> Path {
        Path { path in
            for (index, value) in values.enumerated() {
                let point = Self.point(index, count: values.count, value: value, center, radius)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
    }

    static func point(_ index: Int, count: Int, value: Double, _ center: CGPoint, _ radius: CGFloat) -> CGPoint {
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(max(count, 1))
        return CGPoint(
            x: center.x + radius * value * cos(angle), y: center.y + radius * value * sin(angle))
    }
}
