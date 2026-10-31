import HTSAPI
import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// Perfil > Integrações (spec 2026-10-31, models 1 and 2): the Garmin card, disconnected or connected with its status.
struct IntegrationsScreen: View {
    @Environment(AppModel.self) private var app
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
                    if app.garminStatus?.connected == true { connected } else { disconnected }
                    if let message {
                        Text(message).htsTextStyle(.caption).foregroundStyle(Color.hts.redText)
                    }
                }
            }
        }
        .task(id: app.dataVersion) {
            await app.loadIntegrations()
            guard let athlete = app.athlete, let database = app.database else { return }
            let activities = (try? await ActivityRepository(database).activities(athleteId: athlete.id)) ?? []
            importedCount = activities.count
            lastActivity = activities.last
        }
    }

    private var disconnected: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space4) {
            Text("Corridas e outros treinos do relógio entram no Diário e dão XP. Não contam para a meta da semana.")
                .htsTextStyle(.body).foregroundStyle(Color.hts.greyApp)
            HTSButton("Conectar Garmin", kind: .garmin) {
                Task {
                    working = true
                    message = Self.message(await app.connectGarmin())
                    working = false
                }
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

    private func field(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space1) {
            Text(label).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            Text(verbatim: value).htsTextStyle(.data).foregroundStyle(Color.hts.bone)
        }
    }

    private static func message(_ error: AppModel.IntegrationError?) -> LocalizedStringKey? {
        switch error {
        case nil: nil
        case .unavailable: "A conexão com o Garmin ainda não foi liberada."
        case .offline: "Sem conexão. Tente de novo com internet."
        case .other: "Não foi possível falar com o servidor. Tente de novo."
        }
    }
}
