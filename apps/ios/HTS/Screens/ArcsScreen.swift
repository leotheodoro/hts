import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

struct ArcsScreen: View {
    @Environment(AppModel.self) private var app
    @State private var model: ArcsModel?

    /// Target of `ArcFormSheet`. The form is kept for later but hidden: arcs are loaded from the starter plan for
    /// now, and the app only shows them (#64).
    enum EditTarget: Identifiable {
        case new
        case arc(UUID)
        var id: String {
            switch self {
            case .new: "new"
            case .arc(let id): id.uuidString
            }
        }
    }

    var body: some View {
        ScreenScaffold(title: "Arcos") {
            if let model {
                content(model)
            }
        }
        .task(id: "\(app.athlete?.id.uuidString ?? "")-\(app.dataVersion)") {
            guard let database = app.database, let athlete = app.athlete else { return }
            let model = ArcsModel(database: database, athleteId: athlete.id)
            await model.load()
            self.model = model
        }
    }

    @ViewBuilder private func content(_ model: ArcsModel) -> some View {
        if model.seasons.isEmpty && model.freeArcs.isEmpty {
            PlaceholderCard(label: "TEMPORADAS", text: "Nenhum arco ainda.")
        }
        ForEach(model.seasons) { entry in
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                HStack(spacing: HTSSpacing.space2) {
                    Text(verbatim: "TEMPORADA · \(entry.season.name.uppercased())").htsTextStyle(.label)
                        .foregroundStyle(entry.season.active ? Color.hts.bone : Color.hts.grey)
                    Spacer()
                    if entry.season.active {
                        Text("ATIVA").htsTextStyle(.label).foregroundStyle(Color.hts.oliveInk)
                            .padding(.horizontal, HTSSpacing.space2).padding(.vertical, HTSSpacing.space1)
                            .background(Color.hts.olive)
                    }
                }
                ForEach(entry.summaries) { summary in
                    ArcRow(
                        summary: summary,
                        eve: summary.arc.kind == .special && (model.battle?.isEve(.today) ?? false))
                }
                if !entry.season.active {
                    HTSButton("Ativar temporada", kind: .ghost) { Task { await model.activate(entry.season) } }
                }
            }
        }
        if !model.freeArcs.isEmpty {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Text("SEMPRE DISPONÍVEL").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                ForEach(model.freeArcs) { summary in ArcRow(summary: summary) }
            }
        }
        if let error = model.error {
            Text(verbatim: error).htsTextStyle(.caption).foregroundStyle(Color.hts.redText)
        }
    }
}

struct ArcRow: View {
    let summary: ArcService.Summary
    /// The special arc in the week of A Batalha.
    var eve = false

    private var overdue: Bool {
        summary.arc.status == .current
            && summary.schedule.isOverdue(today: .today, completedSessions: summary.completedSessions)
    }

    var body: some View {
        NotchCard {
            HStack(alignment: .top, spacing: HTSSpacing.space4) {
                if let kanji = summary.arc.kanji {
                    Text(verbatim: kanji).htsTextStyle(.kanji).foregroundStyle(Color.hts.bone)
                        .lineLimit(1).minimumScaleFactor(0.4).frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                    Text(statusLabel).htsTextStyle(.label)
                        .foregroundStyle(overdue || eve ? Color.hts.redText : Color.hts.grey)
                    Text(verbatim: summary.arc.name).htsTextStyle(.uiSection).foregroundStyle(Color.hts.bone)
                    Text(subtitle).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                    if let total = summary.schedule.totalSessions {
                        HStack(spacing: HTSSpacing.space3) {
                            ProgressBar(value: Double(summary.completedSessions) / Double(max(total, 1)))
                            Text(verbatim: String(format: "%02d/%02d", summary.completedSessions, total))
                                .htsTextStyle(.dataSm).foregroundStyle(Color.hts.bone)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statusLabel: LocalizedStringKey {
        if summary.arc.kind == .filler { return "SEMPRE DISPONÍVEL" }
        if eve { return "A VÉSPERA · SEMANA DA BATALHA" }
        if overdue { return "ATRASADO" }
        switch summary.arc.status {
        case .current: return "ATUAL"
        case .queued: return "BLOQUEADO"
        case .completed: return "CONCLUÍDO"
        }
    }

    private var subtitle: LocalizedStringKey {
        let count = summary.schedule.weeklyGoal
        guard let weeks = summary.arc.weeks else { return "\(count) treinos · sem prazo" }
        return weeks == 1 ? "\(count) treinos × 1 semana" : "\(count) treinos × \(weeks) semanas"
    }
}
