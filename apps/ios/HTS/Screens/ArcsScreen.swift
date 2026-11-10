import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

struct ArcsScreen: View {
    @Environment(AppModel.self) private var app
    @State private var model: ArcsModel?
    /// SEMPRE DISPONÍVEL is an accordion, closed by default (#206).
    @State private var showsFreeArcs = UserDefaults.standard.bool(forKey: "HTSOpenFreeArcs")

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
            NavigationLink(value: Route.seasons) {
                HStack(spacing: HTSSpacing.space1) {
                    Text("Temporadas disponíveis").htsTextStyle(.label)
                    Image(systemName: "chevron.right").font(.caption2).accessibilityHidden(true)
                }
                .foregroundStyle(Color.hts.bone)
                .padding(.horizontal, HTSSpacing.space3)
                .frame(minHeight: 44)
                .overlay(Rectangle().strokeBorder(Color.hts.lineStrong, lineWidth: HTSStroke.hair).frame(height: 32))
            }
            .buttonStyle(.plain)
        } content: {
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
        // The other seasons live in Temporadas disponíveis (#204).
        ForEach(model.seasons.filter(\.season.active)) { entry in
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
                    NavigationLink(value: Route.arc(summary.arc.id)) {
                        ArcRow(
                            summary: summary,
                            eve: summary.arc.kind == .special && (model.battle?.isEve(.today) ?? false))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if !model.freeArcs.isEmpty {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showsFreeArcs.toggle() }
                } label: {
                    HStack {
                        Text("SEMPRE DISPONÍVEL").htsTextStyle(.label)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(showsFreeArcs ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Color.hts.grey)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(Text(showsFreeArcs ? "Aberto" : "Fechado"))
                if showsFreeArcs {
                    ForEach(model.freeArcs) { summary in
                        NavigationLink(value: Route.arc(summary.arc.id)) { ArcRow(summary: summary) }
                            .buttonStyle(.plain)
                    }
                }
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
    /// The first open arc of an inactive season (#204): PRÓXIMO, not dimmed.
    var upNext = false

    private var overdue: Bool {
        summary.arc.status == .current
            && summary.schedule.isOverdue(today: .today, completedSessions: summary.completedSessions)
    }

    /// The current arc stands out in `blood`; locked arcs are dimmed (#90).
    private var isCurrent: Bool { summary.arc.status == .current && summary.arc.kind != .filler }
    private var isLocked: Bool {
        summary.arc.status == .queued && summary.arc.kind != .filler && !upNext && !summary.isOpen
    }
    private var nameColor: Color { isLocked ? Color.hts.bone.opacity(HTSOpacity.next) : Color.hts.bone }

    var body: some View {
        NotchCard(border: isCurrent ? Color.hts.blood : Color.hts.line) {
            HStack(alignment: .top, spacing: HTSSpacing.space4) {
                if let kanji = summary.arc.kanji {
                    Text(verbatim: kanji).htsTextStyle(.kanji).foregroundStyle(nameColor)
                        .lineLimit(1).minimumScaleFactor(0.4).frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                    Text(statusLabel).htsTextStyle(.label)
                        .foregroundStyle(overdue || eve || isCurrent ? Color.hts.redText : Color.hts.grey)
                    Text(verbatim: summary.arc.name).htsTextStyle(.uiSection).foregroundStyle(nameColor)
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
        if upNext { return "PRÓXIMO" }
        if summary.isOpen { return "DISPONÍVEL" }
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
