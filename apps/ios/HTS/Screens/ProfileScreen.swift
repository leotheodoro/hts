import HTSAPI
import HTSDesign
import HTSDomain
import HTSPersistence
import PhotosUI
import SwiftUI

/// Avatar, name, @username · patente · nível, then the list of pages and, last, Sair (#143).
struct ProfileScreen: View {
    @Environment(AppModel.self) private var app
    @State private var history: ProgressHistory?
    @State private var choosingPhoto = false
    @State private var showsLibrary = false
    @State private var showsCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var uploading = false
    @State private var photoError: LocalizedStringKey?

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
            Button {
                choosingPhoto = true
            } label: {
                AvatarView(url: account?.avatarUrl.flatMap(URL.init(string:)), name: name)
                    .overlay {
                        if uploading { ProgressView().tint(Color.hts.bone) }
                    }
            }
            .disabled(uploading)
            .accessibilityHint("Toque para trocar a foto")
            .confirmationDialog("Foto de perfil", isPresented: $choosingPhoto) {
                if CameraPicker.isAvailable {
                    Button("Tirar foto") { showsCamera = true }
                }
                Button("Escolher da galeria") { showsLibrary = true }
            }
            .photosPicker(isPresented: $showsLibrary, selection: $libraryItem, matching: .images)
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                libraryItem = nil
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    await upload(data.flatMap(UIImage.init(data:)))
                }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                CameraPicker { image in
                    showsCamera = false
                    Task { await upload(image) }
                }
                .ignoresSafeArea()
            }
            if let photoError {
                Text(photoError).htsTextStyle(.caption).foregroundStyle(Color.hts.redText)
            }
            Text(verbatim: name).htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
                .multilineTextAlignment(.center)
            Text(verbatim: subtitle(username: account?.username)).htsTextStyle(.caption)
                .foregroundStyle(Color.hts.greyApp)
        }
        .frame(maxWidth: .infinity)
    }

    /// Reduces the photo (512 px JPEG) and sends it; the avatar shows the new link when it comes back.
    private func upload(_ image: UIImage?) async {
        guard let image else { return }
        guard let jpeg = AvatarImage.jpeg(from: image) else {
            photoError = "Não foi possível ler a foto."
            return
        }
        uploading = true
        photoError = nil
        let error = await app.uploadAvatar(jpeg: jpeg)
        uploading = false
        photoError =
            switch error {
            case nil: nil
            case .offline: "Sem conexão. Tente de novo com internet."
            case .photoUnavailable: "O envio de fotos ainda não está configurado no servidor."
            case .photoTooLarge: "A foto ficou grande demais. Tente outra."
            default: "Não foi possível enviar a foto. Tente de novo."
            }
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

/// Name, username and e-mail (unique) and the password change, which asks for the current one (#144).
struct AccountScreen: View {
    @Environment(AppModel.self) private var app
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var saving = false
    @State private var accountMessage: Message?

    @State private var current = ""
    @State private var new = ""
    @State private var confirmation = ""
    @State private var changing = false
    @State private var passwordMessage: Message?

    struct Message: Equatable {
        let text: LocalizedStringKey
        let isError: Bool
    }

    var body: some View {
        DetailScaffold {
            Text("Minha conta").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
            VStack(alignment: .leading, spacing: HTSSpacing.space5) {
                HTSTextField(label: "NOME", text: $name, contentType: .name)
                HTSTextField(label: "USERNAME", text: $username, contentType: .username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HTSTextField(label: "E-MAIL", text: $email, contentType: .emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                if hasChanges {
                    HTSButton(saving ? "Salvando…" : "Salvar") { saveAccount() }
                        .disabled(saving || !isFilled)
                }
                message(accountMessage)
            }
            VStack(alignment: .leading, spacing: HTSSpacing.space5) {
                Text("Senha").htsTextStyle(.uiSection).foregroundStyle(Color.hts.bone)
                HTSTextField(label: "SENHA ATUAL", text: $current, secure: true, contentType: .password)
                HTSTextField(label: "NOVA SENHA", text: $new, secure: true, contentType: .newPassword)
                HTSTextField(
                    label: "CONFIRMAR NOVA SENHA", text: $confirmation, secure: true, contentType: .newPassword)
                HTSButton(changing ? "Alterando…" : "Alterar senha", kind: .ghost) { changePassword() }
                    .disabled(changing || current.isEmpty || new.isEmpty || confirmation.isEmpty)
                message(passwordMessage)
            }
        }
        .onAppear(perform: reset)
    }

    private var account: Account? { app.session?.account }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespaces) }

    private var isFilled: Bool { [name, username, email].allSatisfy { !trimmed($0).isEmpty } }

    private var hasChanges: Bool {
        guard let account else { return false }
        return trimmed(name) != account.name || trimmed(username) != account.username
            || trimmed(email) != account.email
    }

    private func reset() {
        guard let account else { return }
        name = account.name
        username = account.username
        email = account.email
    }

    @ViewBuilder private func message(_ message: Message?) -> some View {
        if let message {
            Text(message.text).htsTextStyle(.caption)
                .foregroundStyle(message.isError ? Color.hts.redText : Color.hts.greyApp)
        }
    }

    private func saveAccount() {
        guard let account else { return }
        saving = true
        accountMessage = nil
        let changed = { (value: String, old: String) in self.trimmed(value) == old ? nil : self.trimmed(value) }
        Task {
            let error = await app.updateAccount(
                name: changed(name, account.name), username: changed(username, account.username),
                email: changed(email, account.email))
            saving = false
            if let error {
                accountMessage = Message(text: text(for: error), isError: true)
            } else {
                reset()
                accountMessage = Message(text: "Dados salvos.", isError: false)
            }
        }
    }

    private func changePassword() {
        passwordMessage = nil
        guard new.count >= 8 else {
            passwordMessage = Message(text: "A nova senha precisa de pelo menos 8 caracteres.", isError: true)
            return
        }
        guard new == confirmation else {
            passwordMessage = Message(text: "As senhas não conferem.", isError: true)
            return
        }
        changing = true
        Task {
            let error = await app.changePassword(current: current, new: new)
            changing = false
            if let error {
                passwordMessage = Message(text: text(for: error), isError: true)
            } else {
                current = ""
                new = ""
                confirmation = ""
                passwordMessage = Message(text: "Senha alterada. Os outros aparelhos saíram da conta.", isError: false)
            }
        }
    }

    private func text(for error: AppModel.AccountError) -> LocalizedStringKey {
        switch error {
        case .usernameTaken: "Esse username já está em uso."
        case .emailTaken: "Esse e-mail já está em uso."
        case .wrongPassword: "Senha atual incorreta."
        case .offline: "Sem conexão. Tente de novo com internet."
        case .photoUnavailable, .photoTooLarge, .other: "Não foi possível salvar. Tente de novo."
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
