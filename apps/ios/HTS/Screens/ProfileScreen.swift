import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

struct ProfileScreen: View {
    @Environment(AppModel.self) private var app
    @State private var name = ""
    @State private var rest = Athlete.defaultRestSeconds
    @State private var titles: [UnlockedTitle] = []
    @State private var attributes: [Attribute: AttributeLevel] = [:]

    var body: some View {
        ScreenScaffold(title: "Perfil") {
            settings
            loadGuide
            syncSection
            BattleSettings()
            titlesSection
            attributesSection
            #if DEBUG
                DiagnosticsSection()
            #endif
        }
        .task(
            id: "\(app.athlete?.id.uuidString ?? "")-\(app.activeSession?.id.uuidString ?? "none")-\(app.dataVersion)"
        ) {
            guard let athlete = app.athlete else { return }
            name = athlete.displayName
            rest = athlete.defaultRestSeconds
            if let database = app.database {
                titles = (try? await ProgressService(database).titles(athleteId: athlete.id)) ?? []
                attributes = (try? await ProgressService(database).attributeLevels(athleteId: athlete.id)) ?? [:]
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space4) {
            Text("Ajustes").htsTextStyle(.uiSection)
            HTSTextField(label: "NOME", text: $name, prompt: "Seu nome")
                .onSubmit { save() }
            HTSStepper("DESCANSO PADRÃO", value: $rest, in: 15...600, step: 15) {
                RestTimer.format(TimeInterval($0))
            }
            .onChange(of: rest) { save() }
            Text("Vale para exercícios sem descanso próprio.").htsTextStyle(.caption)
                .foregroundStyle(Color.hts.greyApp)
            if name.trimmingCharacters(in: .whitespaces) != app.athlete?.displayName {
                HTSButton("Salvar nome", kind: .ghost) { save() }
            }
        }
    }

    /// FOR, EXP, GÁS, COR, MOB, each with its own level (docs/decisions/0023).
    private var attributesSection: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                Text("ATRIBUTOS").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                ForEach(Attribute.allCases, id: \.self) { attribute in
                    let level = attributes[attribute] ?? AttributeLevel(xp: 0, level: 1)
                    let progress = Progression().levelProgress(xp: level.xp)
                    VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(verbatim: attribute.abbreviation).htsTextStyle(.data).frame(
                                width: 64, alignment: .leading)
                            Text(attribute.label).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                            Spacer()
                            Text(verbatim: "NÍVEL \(level.level)").htsTextStyle(.label)
                        }
                        ProgressBar(value: progress.fraction)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var titlesSection: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space3) {
            HStack {
                Text("Títulos").htsTextStyle(.uiSection)
                Spacer()
                Text(verbatim: "\(titles.count)/\(TitleID.allCases.count)").htsTextStyle(.dataSm)
            }
            ForEach(TitleID.allCases, id: \.self) { id in
                let unlocked = titles.first { $0.id == id }
                HStack(alignment: .top, spacing: HTSSpacing.space3) {
                    VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                        Text(id.name).htsTextStyle(.bodyStrong)
                            .foregroundStyle(unlocked != nil ? Color.hts.oliveInk : Color.hts.greyApp)
                        Text(id.condition).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                    }
                    Spacer()
                    if let unlocked {
                        Text(verbatim: unlocked.unlockedOn.short).htsTextStyle(.dataSm)
                            .foregroundStyle(Color.hts.oliveInk)
                    }
                }
                .padding(HTSSpacing.space3)
                .background(unlocked != nil ? Color.hts.olive : Color.clear)
                .overlay(
                    Rectangle().strokeBorder(unlocked != nil ? Color.clear : Color.hts.line, lineWidth: HTSStroke.hair)
                )
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var syncSection: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Text("SINCRONIZAÇÃO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                Group {
                    switch app.syncState {
                    case .idle:
                        Text(
                            app.apiConfiguration?.token == nil
                                ? "Token da API não configurado. Os dados ficam no aparelho."
                                : "Ainda não sincronizado.")
                    case .syncing:
                        Text("Sincronizando…")
                    case .synced(let date):
                        Text("Sincronizado às \(date.formatted(date: .omitted, time: .shortened)).")
                    case .failed(let message):
                        Text(verbatim: message).foregroundStyle(Color.hts.redText)
                    }
                }
                .htsTextStyle(.caption)
                .foregroundStyle(Color.hts.greyApp)
                HTSButton("Sincronizar agora", kind: .ghost) { Task { await app.sync() } }
                    .disabled(app.syncState == .syncing || app.apiConfiguration?.token == nil)
            }
        }
    }

    private var loadGuide: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Text("ORIENTAÇÕES DE CARGA").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                ForEach(LoadGuide.allCases, id: \.self) { guide in
                    HStack {
                        Text(verbatim: guide.repRange).htsTextStyle(.body)
                        Spacer()
                        Text(verbatim: guide.label).htsTextStyle(.dataSm)
                    }
                }
            }
        }
    }

    private func save() {
        guard var athlete = app.athlete, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        athlete.displayName = name
        athlete.defaultRestSeconds = rest
        Task { await app.updateAthlete(athlete) }
    }
}

#if DEBUG
    /// Debug-only check that the local database and the API are wired up.
    struct DiagnosticsSection: View {
        @Environment(AppModel.self) private var model

        var body: some View {
            VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                Text("Diagnóstico").htsTextStyle(.uiSection)
                NotchCard {
                    VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                        Text("ATLETA LOCAL").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        if let athlete = model.athlete {
                            row("Nome", athlete.displayName)
                            row("ID", athlete.id.uuidString.lowercased())
                            row("Descanso padrão", "\(athlete.defaultRestSeconds) s")
                        } else if let error = model.databaseError {
                            Text(verbatim: error).htsTextStyle(.caption).foregroundStyle(Color.hts.redText)
                        } else {
                            Text("Carregando").htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                        }
                    }
                }
                NotchCard {
                    VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                        Text("API · GET /health").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        row("URL", model.apiConfiguration?.baseURL.absoluteString ?? "—")
                        healthRow
                    }
                }
                HTSButton("Verificar de novo", kind: .ghost) {
                    Task { await model.checkHealth() }
                }
            }
        }

        @ViewBuilder private var healthRow: some View {
            switch model.health {
            case .unknown, .checking:
                row("Estado", String(localized: "Verificando"))
            case .online(let version):
                row("Estado", String(localized: "Online · versão \(version)"))
            case .offline(let message):
                VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                    Text("Offline").htsTextStyle(.bodyStrong).foregroundStyle(Color.hts.redText)
                    Text(verbatim: message).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                }
            }
        }

        private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: HTSSpacing.space3) {
                Text(label).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                Spacer(minLength: HTSSpacing.space2)
                Text(verbatim: value).htsTextStyle(.dataSm).foregroundStyle(Color.hts.bone)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1).truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }
#endif

/// Name, date and result of A Batalha.
private struct BattleSettings: View {
    @Environment(AppModel.self) private var app
    @State private var battle: Battle?
    @State private var name = ""
    @State private var date = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space4) {
            Text("A Batalha").htsTextStyle(.uiSection)
            HTSTextField(label: "COMPETIÇÃO", text: $name, prompt: "Copa Hard To Submit")
            HTSDateField("DATA", date: $date)
            if let battle, battle.daysUntil(.today) <= 0 {
                VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                    FieldLabel(text: "RESULTADO")
                    Picker("Resultado", selection: Binding(get: { battle.result }, set: { save(result: $0) })) {
                        Text("Sem resultado").tag(BattleResult?.none)
                        ForEach(BattleResult.allCases, id: \.self) { Text($0.label).tag(BattleResult?.some($0)) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.hts.bone)
                }
            }
            HTSButton(battle == nil ? "Cadastrar Batalha" : "Salvar Batalha", kind: .ghost) {
                save(result: battle?.result)
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .task(id: app.athlete?.id) {
            guard let database = app.database, let athlete = app.athlete else { return }
            battle = try? await BattleRepository(database).current(athleteId: athlete.id, today: .today)
            if let battle {
                name = battle.name
                date = battle.date.date
            }
        }
    }

    private func save(result: BattleResult?) {
        guard let database = app.database, let athlete = app.athlete else { return }
        Task {
            let localDate = LocalDate(date, in: .current)
            let season = try await SeasonService(database).activeSeason(athleteId: athlete.id)
            var updated =
                battle
                ?? Battle(
                    id: UUIDv7.make(), athleteId: athlete.id, seasonId: season?.id, name: name, date: localDate,
                    createdAt: .now)
            updated.name = name.trimmingCharacters(in: .whitespaces)
            updated.date = localDate
            updated.result = result
            try await BattleRepository(database).save(updated)
            battle = updated
        }
    }
}
