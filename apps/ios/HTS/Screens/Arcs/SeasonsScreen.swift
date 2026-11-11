import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// Temporadas disponíveis (#204): every season, the active one marked. The Arcos tab shows only the active one.
struct SeasonsScreen: View {
    @Environment(AppModel.self) private var app
    @State private var model: ArcsModel?

    var body: some View {
        DetailScaffold {
            Text("Temporadas disponíveis").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
            if let model {
                if model.seasons.isEmpty {
                    PlaceholderCard(label: "TEMPORADAS", text: "Nenhuma temporada ainda.")
                }
                ForEach(model.seasons) { entry in
                    NavigationLink(value: Route.season(entry.season.id)) { row(entry) }
                        .buttonStyle(.plain)
                }
            }
        }
        .task(id: "\(app.athlete?.id.uuidString ?? "")-\(app.dataVersion)") {
            guard let database = app.database, let athlete = app.athlete else { return }
            let model = self.model ?? ArcsModel(database: database, athleteId: athlete.id)
            await model.load()
            self.model = model
        }
    }

    private func row(_ entry: ArcsModel.SeasonArcs) -> some View {
        let arcs = entry.summaries.filter { $0.arc.kind != .filler }
        let completed = arcs.filter { $0.arc.status == .completed }.count
        return NotchCard(border: entry.season.active ? Color.hts.bone : Color.hts.line) {
            HStack(spacing: HTSSpacing.space3) {
                VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                    Text(verbatim: entry.season.name).htsTextStyle(.uiSection).foregroundStyle(Color.hts.bone)
                    Text(
                        "\(arcs.count) \(arcs.count == 1 ? "arco" : "arcos") · \(completed) \(completed == 1 ? "concluído" : "concluídos")"
                    )
                    .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                }
                Spacer()
                if entry.season.active { ActiveSeasonBadge() }
                Image(systemName: "chevron.right").foregroundStyle(Color.hts.greyApp).accessibilityHidden(true)
            }
        }
    }
}

/// ATIVA on `olive`, as on the Arcos tab.
struct ActiveSeasonBadge: View {
    var body: some View {
        Text("ATIVA").htsTextStyle(.label).foregroundStyle(Color.hts.oliveInk)
            .padding(.horizontal, HTSSpacing.space2).padding(.vertical, HTSSpacing.space1)
            .background(Color.hts.olive)
    }
}

/// One season (#204): its arcs in order, each opening the arc, and "Ativar temporada" with a confirmation that says
/// which arc restarts.
struct SeasonScreen: View {
    let seasonId: UUID

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var model: ArcsModel?
    @State private var confirming = false

    var body: some View {
        DetailScaffold {
            if let model, let entry = model.seasons.first(where: { $0.season.id == seasonId }) {
                HStack(spacing: HTSSpacing.space3) {
                    Text(verbatim: entry.season.name).htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
                    Spacer()
                    if entry.season.active { ActiveSeasonBadge() }
                }
                ForEach(entry.summaries.filter { $0.arc.kind != .filler }) { summary in
                    NavigationLink(value: Route.arc(summary.arc.id)) {
                        ArcRow(summary: summary, upNext: summary.arc.id == model.upNextArcId(in: entry))
                    }
                    .buttonStyle(.plain)
                }
                if entry.season.active { deactivation(model, entry.season) } else { activation(model, entry.season) }
                if let error = model.error {
                    Text(verbatim: error).htsTextStyle(.caption).foregroundStyle(Color.hts.redText)
                }
            }
        }
        .task(id: "\(app.athlete?.id.uuidString ?? "")-\(app.dataVersion)") {
            guard let database = app.database, let athlete = app.athlete else { return }
            let model = self.model ?? ArcsModel(database: database, athleteId: athlete.id)
            await model.load()
            self.model = model
        }
    }

    /// "Desativar temporada" (#214): no season stays active, with the same kind of confirmation as a switch.
    @ViewBuilder private func deactivation(_ model: ArcsModel, _ season: Season) -> some View {
        if confirming {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Text("Desativar \(season.name)?").htsTextStyle(.bodyStrong).foregroundStyle(Color.hts.redText)
                Text(verbatim: model.deactivationNote()).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                HTSButton("Desativar temporada") {
                    Task {
                        await model.deactivate(season)
                        confirming = false
                        app.noteLocalChange()
                        if model.error == nil { dismiss() }
                    }
                }
                HTSButton("Manter \(season.name)", kind: .ghost) { confirming = false }
            }
            .padding(HTSSpacing.space5)
            .background(Color.hts.bloodDeep, in: NotchShape())
            .overlay(NotchShape().strokeBorder(Color.hts.blood, lineWidth: HTSStroke.hair))
        } else {
            HTSButton("Desativar temporada", kind: .ghost) { confirming = true }
        }
    }

    @ViewBuilder private func activation(_ model: ArcsModel, _ season: Season) -> some View {
        if confirming {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Text("Ativar \(season.name)?").htsTextStyle(.bodyStrong).foregroundStyle(Color.hts.redText)
                Text(verbatim: model.activationNote(for: season))
                    .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                HTSButton("Ativar temporada") {
                    Task {
                        await model.activate(season)
                        confirming = false
                        app.noteLocalChange()
                        if model.error == nil { dismiss() }
                    }
                }
                if let active = model.activeSeason {
                    HTSButton("Manter \(active.name)", kind: .ghost) { confirming = false }
                } else {
                    HTSButton("Cancelar", kind: .ghost) { confirming = false }
                }
            }
            .padding(HTSSpacing.space5)
            .background(Color.hts.bloodDeep, in: NotchShape())
            .overlay(NotchShape().strokeBorder(Color.hts.blood, lineWidth: HTSStroke.hair))
        } else {
            HTSButton("Ativar temporada", kind: .ghost) { confirming = true }
        }
    }
}
