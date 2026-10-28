import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

struct StatusScreen: View {
    @Environment(AppModel.self) private var app
    @State private var model: StatusModel?

    var body: some View {
        ScreenScaffold(title: "Status") {
            if let athlete = app.athlete, let model {
                athleteCard(athlete, model)
                workoutCard(model)
                weekCard(model)
            }
        }
        .task(id: "\(app.athlete?.id.uuidString ?? "")-\(app.activeSession?.id.uuidString ?? "none")") {
            guard let database = app.database, let athlete = app.athlete else { return }
            let model = self.model ?? StatusModel(database: database, athleteId: athlete.id)
            await model.load()
            self.model = model
        }
    }

    private func athleteCard(_ athlete: Athlete, _ model: StatusModel) -> some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                HStack(spacing: HTSSpacing.space4) {
                    if let rank = model.history?.rank { RankBadge(rank: rank) }
                    VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                        Text(verbatim: athlete.displayName).htsTextStyle(.uiSection)
                        if let history = model.history {
                            Text(verbatim: "\(history.rank.name.uppercased()) · NÍVEL \(history.level)")
                                .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        }
                    }
                }
                if let level = model.levelProgress, let history = model.history {
                    VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                        ProgressBar(value: level.fraction, highlighted: true).frame(height: HTSStroke.bar)
                        HStack {
                            Text("XP").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                            Spacer()
                            Text(verbatim: "\(history.totalXp) / \(level.end)").htsTextStyle(.dataSm)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func workoutCard(_ model: StatusModel) -> some View {
        if let session = app.activeSession {
            NotchCard {
                VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                    Text("TREINO EM ANDAMENTO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    Text(verbatim: "\(session.planSnapshot.letter) · \(session.planSnapshot.name)")
                        .htsTextStyle(.uiSection)
                    HTSButton("Continuar") { app.showsActiveSession = true }
                }
            }
        } else if let next = model.next {
            NotchCard {
                VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                    Text("PRÓXIMO TREINO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    Text(verbatim: "\(next.plan.template.letter) · \(next.plan.template.name)")
                        .htsTextStyle(.uiSection)
                    if let total = next.total {
                        HStack(spacing: HTSSpacing.space3) {
                            ProgressBar(value: Double(next.completed) / Double(max(total, 1)))
                            Text(verbatim: String(format: "%02d/%02d", next.completed, total)).htsTextStyle(.dataSm)
                        }
                    }
                    Text(verbatim: next.arc.name).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                    if next.plan.blocks.isEmpty {
                        Text("Este treino ainda não tem exercícios. Edite em Arcos.")
                            .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                    } else {
                        HTSButton("Iniciar treino") { Task { await app.startWorkout(next.plan) } }
                    }
                }
            }
        } else {
            PlaceholderCard(label: "PRÓXIMO TREINO", text: "Nenhum arco atual. Crie um em Arcos.")
        }
    }

    private func weekCard(_ model: StatusModel) -> some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                HStack {
                    Text("ESTA SEMANA").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    Spacer()
                    Text(verbatim: String(format: "%02d/%02d", model.weekDone, model.weekGoal)).htsTextStyle(.data)
                }
                if model.weekGoal > 0 {
                    HStack(spacing: HTSSpacing.space2) {
                        ForEach(0..<model.weekGoal, id: \.self) { index in
                            Rectangle()
                                .fill(index < model.weekDone ? Color.hts.bone : Color.hts.track)
                                .frame(height: HTSStroke.bar)
                        }
                    }
                }
            }
        }
    }
}
