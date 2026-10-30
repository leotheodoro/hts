import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// Avatar, name, @username · patente · nível, then the list of pages and, last, Sair (#143).
struct ProfileScreen: View {
    @Environment(AppModel.self) private var app
    @State private var history: ProgressHistory?

    var body: some View {
        ScreenScaffold(title: "Perfil") {
            header
            menu
            footer
        }
        .task(id: "\(app.athlete?.id.uuidString ?? "")-\(app.dataVersion)") {
            guard let athlete = app.athlete, let database = app.database else { return }
            history = try? await ProgressService(database).history(athleteId: athlete.id).history
        }
    }

    private var header: some View {
        let account = app.session?.account
        let name = account?.name ?? app.athlete?.displayName ?? ""
        return VStack(spacing: HTSSpacing.space3) {
            AvatarView(url: account?.avatarUrl.flatMap(URL.init(string:)), name: name)
            Text(verbatim: name).htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
                .multilineTextAlignment(.center)
            Text(verbatim: subtitle(username: account?.username)).htsTextStyle(.caption)
                .foregroundStyle(Color.hts.greyApp)
        }
        .frame(maxWidth: .infinity)
    }

    /// "@leotheodoro · Recruta · Nível 3".
    private func subtitle(username: String?) -> String {
        var parts: [String] = []
        if let username { parts.append("@\(username)") }
        if let history {
            parts.append(history.rank.name)
            parts.append(String(localized: "Nível \(history.level)"))
        }
        return parts.joined(separator: " · ")
    }

    private var menu: some View {
        VStack(spacing: 0) {
            row("Minha conta", .account)
            row("Configurações de treino", .trainingSettings)
            row("A Batalha", .battle)
            row("Conquistas", .titles)
            row("Atributos", .attributes)
        }
        .overlay(alignment: .top) { Rectangle().fill(Color.hts.line).frame(height: HTSStroke.hair) }
    }

    private func row(_ title: LocalizedStringKey, _ route: Route) -> some View {
        NavigationLink(value: route) {
            HStack {
                Text(title).htsTextStyle(.body).foregroundStyle(Color.hts.bone)
                Spacer()
                Image(systemName: "chevron.right").fontWeight(.light).foregroundStyle(Color.hts.grey)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hts.line).frame(height: HTSStroke.hair) }
    }

    private var footer: some View {
        VStack(spacing: HTSSpacing.space3) {
            Group {
                if let date = app.lastSyncedAt {
                    Text("Última sincronização: \(date.formatted(.relative(presentation: .named)))")
                } else {
                    Text("Ainda não sincronizado.")
                }
            }
            .htsTextStyle(.caption)
            .foregroundStyle(Color.hts.greyApp)
            HTSButton("Sair", kind: .ghost) { Task { await app.signOut() } }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The account, read only until #144 makes it editable.
struct AccountScreen: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        DetailScaffold {
            Text("Minha conta").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
            if let account = app.session?.account {
                VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                    Text(verbatim: account.name).htsTextStyle(.bodyStrong).foregroundStyle(Color.hts.bone)
                    Text(verbatim: "@\(account.username)").htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                    Text(verbatim: account.email).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                }
            }
        }
    }
}

/// Default rest and the load guidelines.
struct TrainingSettingsScreen: View {
    @Environment(AppModel.self) private var app
    @State private var rest = Athlete.defaultRestSeconds

    var body: some View {
        DetailScaffold {
            Text("Configurações de treino").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
            VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                HTSStepper("DESCANSO PADRÃO", value: $rest, in: 15...600, step: 15) {
                    RestTimer.format(TimeInterval($0))
                }
                .onChange(of: rest) { save() }
                Text("Vale para exercícios sem descanso próprio.").htsTextStyle(.caption)
                    .foregroundStyle(Color.hts.greyApp)
            }
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
        .onAppear { rest = app.athlete?.defaultRestSeconds ?? Athlete.defaultRestSeconds }
    }

    private func save() {
        guard var athlete = app.athlete, athlete.defaultRestSeconds != rest else { return }
        athlete.defaultRestSeconds = rest
        Task { await app.updateAthlete(athlete) }
    }
}

struct BattleScreen: View {
    var body: some View {
        DetailScaffold { BattleSettings() }
    }
}

/// Titles unlocked and still locked ("Conquistas").
struct TitlesScreen: View {
    @Environment(AppModel.self) private var app
    @State private var titles: [UnlockedTitle] = []

    var body: some View {
        DetailScaffold {
            HStack(alignment: .firstTextBaseline) {
                Text("Conquistas").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
                Spacer()
                Text(verbatim: "\(titles.count)/\(TitleID.allCases.count)").htsTextStyle(.dataSm)
                    .foregroundStyle(Color.hts.bone)
            }
            VStack(spacing: HTSSpacing.space3) {
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
                        Rectangle().strokeBorder(
                            unlocked != nil ? Color.clear : Color.hts.line, lineWidth: HTSStroke.hair)
                    )
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .task(id: app.dataVersion) {
            guard let athlete = app.athlete, let database = app.database else { return }
            titles = (try? await ProgressService(database).titles(athleteId: athlete.id)) ?? []
        }
    }
}

/// FOR, EXP, GÁS, COR, MOB, each with its own level (docs/decisions/0023).
struct AttributesScreen: View {
    @Environment(AppModel.self) private var app
    @State private var attributes: [Attribute: AttributeLevel] = [:]

    var body: some View {
        DetailScaffold {
            Text("Atributos").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
            NotchCard {
                VStack(alignment: .leading, spacing: HTSSpacing.space4) {
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
        .task(id: app.dataVersion) {
            guard let athlete = app.athlete, let database = app.database else { return }
            attributes = (try? await ProgressService(database).attributeLevels(athleteId: athlete.id)) ?? [:]
        }
    }
}

/// Name, date and result of A Batalha.
struct BattleSettings: View {
    @Environment(AppModel.self) private var app
    @State private var battle: Battle?
    @State private var name = ""
    @State private var date = Date.now
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space4) {
            Text("A Batalha").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
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
            if hasChanges {
                HTSButton(battle == nil ? "Cadastrar Batalha" : "Salvar Batalha", kind: .ghost) {
                    save(result: battle?.result)
                }
            }
            if let error {
                Text(verbatim: error).htsTextStyle(.caption).foregroundStyle(Color.hts.redText)
            }
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

    /// The save button only shows when the name or the date differ from what is saved (#88).
    private var hasChanges: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        guard let battle else { return true }
        return trimmed != battle.name || LocalDate(date, in: .current) != battle.date
    }

    private func save(result: BattleResult?) {
        guard let database = app.database, let athlete = app.athlete else { return }
        Task {
            do {
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
                error = nil
            } catch {
                self.error = String(describing: error)
            }
        }
    }
}
