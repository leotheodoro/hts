import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

struct ProfileScreen: View {
    @Environment(AppModel.self) private var app
    @State private var name = ""
    @State private var rest = Athlete.defaultRestSeconds

    var body: some View {
        ScreenScaffold(title: "Perfil") {
            settings
            loadGuide
            PlaceholderCard(label: "ATRIBUTOS E TÍTULOS", text: "Chegam quando a escala dos atributos for definida.")
            #if DEBUG
                DiagnosticsSection()
            #endif
        }
        .task(id: app.athlete?.id) {
            guard let athlete = app.athlete else { return }
            name = athlete.displayName
            rest = athlete.defaultRestSeconds
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space4) {
            Text("Ajustes").htsTextStyle(.uiSection)
            HTSTextField(label: "NOME", text: $name, prompt: "Seu nome")
                .onSubmit { save() }
            Stepper(value: $rest, in: 15...600, step: 15) {
                HStack {
                    FieldLabel(text: "DESCANSO PADRÃO")
                    Spacer()
                    Text(verbatim: RestTimer.format(TimeInterval(rest))).htsTextStyle(.data)
                }
            }
            .onChange(of: rest) { save() }
            Text("Vale para exercícios sem descanso próprio.").htsTextStyle(.caption)
                .foregroundStyle(Color.hts.greyApp)
            if name.trimmingCharacters(in: .whitespaces) != app.athlete?.displayName {
                HTSButton("Salvar nome", kind: .ghost) { save() }
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
