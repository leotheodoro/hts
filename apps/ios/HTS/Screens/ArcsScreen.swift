import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

struct ArcsScreen: View {
    @Environment(AppModel.self) private var app
    @State private var model: ArcsModel?
    @State private var editing: EditTarget?

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
        .task(id: app.athlete?.id) {
            guard let database = app.database, let athlete = app.athlete else { return }
            let model = ArcsModel(database: database, athleteId: athlete.id)
            await model.load()
            self.model = model
            #if DEBUG
                // `-HTSOpenArcForm new` or `-HTSOpenArcForm first` opens the form (screenshots, UI checks).
                switch UserDefaults.standard.string(forKey: "HTSOpenArcForm") {
                case "new": editing = .new
                case "first": editing = model.summaries.first.map { .arc($0.arc.id) }
                default: break
                }
            #endif
        }
        .sheet(item: $editing) { target in
            if let model {
                ArcFormSheet(model: model, target: target)
            }
        }
    }

    @ViewBuilder private func content(_ model: ArcsModel) -> some View {
        if let saga = model.saga {
            Text(verbatim: saga.name.uppercased()).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
        }
        if model.summaries.isEmpty {
            PlaceholderCard(label: "SAGA", text: "Crie o primeiro arco para começar a temporada.")
        }
        ForEach(model.summaries) { summary in
            Button {
                editing = .arc(summary.arc.id)
            } label: {
                ArcRow(summary: summary, eve: summary.arc.kind == .special && (model.battle?.isEve(.today) ?? false))
            }
            .buttonStyle(.plain)
        }
        HTSButton("Criar arco", kind: model.summaries.isEmpty ? .primary : .ghost) {
            editing = .new
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
        if eve { return "A VÉSPERA · SEMANA DA BATALHA" }
        if overdue { return "ATRASADO" }
        switch summary.arc.status {
        case .current: return "ATUAL"
        case .queued: return "NA FILA"
        case .completed: return "CONCLUÍDO"
        }
    }

    private var subtitle: LocalizedStringKey {
        let count = summary.schedule.weeklyGoal
        guard let weeks = summary.arc.weeks else { return "\(count) treinos · sem prazo" }
        return "\(count) treinos × \(weeks) semanas"
    }
}
