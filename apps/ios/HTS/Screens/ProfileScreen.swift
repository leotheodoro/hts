import HTSDesign
import SwiftUI

struct ProfileScreen: View {
    var body: some View {
        ScreenScaffold(title: "Perfil") {
            PlaceholderCard(label: "ATRIBUTOS", text: "Atributos, títulos e ajustes chegam nos próximos tickets.")
            #if DEBUG
                DiagnosticsSection()
            #endif
        }
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
                    .textSelection(.enabled)
            }
        }
    }
#endif
