import AuthenticationServices
import HTSAPI
import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// Perfil > Integrações (spec 2026-10-31, models 1 and 2): the Garmin card, disconnected or connected with its status.
struct IntegrationsScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var lastActivity: ImportedActivity?
    @State private var importedCount = 0
    @State private var working = false
    @State private var confirmingDisconnect = false
    @State private var message: LocalizedStringKey?

    var body: some View {
        DetailScaffold {
            Text("Integrações").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
            NotchCard {
                VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                    HStack {
                        GarminBadge()
                        Spacer()
                        if app.garminStatus?.connected == true {
                            Text("Conectado").htsTextStyle(.label).foregroundStyle(Color.hts.bone)
                        }
                    }
                    if let status = app.garminStatus {
                        if status.connected { connected } else { disconnected }
                    } else {
                        unknown
                    }
                    if let message {
                        Text(message).htsTextStyle(.caption).foregroundStyle(Color.hts.redText)
                    }
                }
            }
        }
        // Keyed by the athlete too: the page can open before the athlete loads.
        .task(id: "\(app.athlete?.id.uuidString ?? "")-\(app.dataVersion)") {
            await app.loadIntegrations()
            guard let athlete = app.athlete, let database = app.database else { return }
            let activities = (try? await ActivityRepository(database).activities(athleteId: athlete.id)) ?? []
            importedCount = activities.count
            lastActivity = activities.last
        }
    }

    /// Not answered yet: never shown as "disconnected", which would invite connecting again (#188).
    @ViewBuilder private var unknown: some View {
        if app.integrationsError == nil || app.checkingIntegrations {
            HStack(spacing: HTSSpacing.space2) {
                ProgressView().tint(Color.hts.grey)
                Text("Verificando a conexão…").htsTextStyle(.body).foregroundStyle(Color.hts.greyApp)
            }
        } else {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Text("Não foi possível verificar a conexão agora.")
                    .htsTextStyle(.body).foregroundStyle(Color.hts.greyApp)
                HTSButton("Tentar de novo", kind: .ghost) {
                    Task { await app.loadIntegrations() }
                }
            }
        }
    }

    private var disconnected: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space4) {
            Text("Corridas e outros treinos do relógio entram no Diário e dão XP. Não contam para a meta da semana.")
                .htsTextStyle(.body).foregroundStyle(Color.hts.greyApp)
            HTSButton("Conectar Garmin", kind: .garmin) {
                Task { await connect() }
            }
            .disabled(working)
        }
    }

    private var connected: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space4) {
            if let since = app.garminStatus?.connectedAt {
                field("CONECTADO DESDE", since.formatted(date: .abbreviated, time: .omitted))
            }
            if let lastActivity {
                VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                    Text("ÚLTIMO TREINO RECEBIDO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    HStack(spacing: HTSSpacing.space1) {
                        Text(lastActivity.typeLabel)
                        Text(verbatim: "·")
                        Text(lastActivity.startedAt.formatted(.relative(presentation: .named)))
                    }
                    .htsTextStyle(.body).foregroundStyle(Color.hts.bone)
                }
            }
            field("TREINOS IMPORTADOS", String(format: "%02d", importedCount))
            if confirmingDisconnect {
                VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                    Text("Desconectar o Garmin? Os treinos já importados continuam no Diário.")
                        .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                    HTSButton("Desconectar", kind: .ghost) {
                        Task {
                            working = true
                            message = Self.message(await app.disconnectGarmin())
                            working = false
                            confirmingDisconnect = false
                        }
                    }
                    .disabled(working)
                    Button("Cancelar") { confirmingDisconnect = false }
                        .htsTextStyle(.body).foregroundStyle(Color.hts.grey)
                }
            } else {
                HTSButton("Desconectar", kind: .ghost) { confirmingDisconnect = true }
            }
        }
    }

    /// The Garmin page in a web authentication session; the API's callback brings the outcome back.
    private func connect() async {
        working = true
        defer { working = false }
        message = nil
        switch await app.garminLoginPage() {
        case .failure(let error):
            message = Self.message(error)
        case .success(let page):
            do {
                let back = try await webAuthenticationSession.authenticate(
                    using: page, callbackURLScheme: GarminLogin.callbackScheme)
                switch GarminLogin.status(from: back) {
                case .connected: await app.loadIntegrations()
                case .denied: message = "Conexão cancelada no Garmin."
                case .failed: message = "Não foi possível conectar ao Garmin. Tente de novo."
                }
            } catch ASWebAuthenticationSessionError.canceledLogin {
                // Closed by the athlete: nothing to say.
            } catch {
                message = "Não foi possível abrir o login do Garmin."
            }
        }
    }

    private func field(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space1) {
            Text(label).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            Text(verbatim: value).htsTextStyle(.data).foregroundStyle(Color.hts.bone)
        }
    }

    private static func message(_ error: AppModel.IntegrationError?) -> LocalizedStringKey? {
        switch error {
        case nil: nil
        case .unavailable: "A conexão com o Garmin ainda não está configurada no servidor."
        case .offline: "Sem conexão. Tente de novo com internet."
        case .other: "Não foi possível falar com o servidor. Tente de novo."
        }
    }
}
