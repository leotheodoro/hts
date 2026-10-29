import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

struct HomeScreen: View {
    @Environment(AppModel.self) private var app
    @State private var model: HomeModel?

    var body: some View {
        ScreenScaffold(title: "Home") {
            if let athlete = app.athlete, let model {
                athleteCard(athlete, model)
                if let battle = model.battle, battle.daysUntil(.today) >= 0 { battleCard(battle) }
                workoutCard(model)
                weekCard(model)
            }
        }
        .task(
            id: "\(app.athlete?.id.uuidString ?? "")-\(app.activeSession?.id.uuidString ?? "none")-\(app.dataVersion)"
        ) {
            guard let database = app.database, let athlete = app.athlete else { return }
            let model = self.model ?? HomeModel(database: database, athleteId: athlete.id)
            await model.load()
            self.model = model
        }
    }

    private func athleteCard(_ athlete: Athlete, _ model: HomeModel) -> some View {
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

    @ViewBuilder private func workoutCard(_ model: HomeModel) -> some View {
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
            // The whole card opens the workout page; workouts start only there (#86, #102).
            NavigationLink(value: Route.workout(templateId: next.plan.template.id)) {
                NotchCard {
                    HStack(spacing: HTSSpacing.space3) {
                        VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                            Text("PRÓXIMO TREINO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                            Text(verbatim: "\(next.plan.template.letter) · \(next.plan.template.name)")
                                .htsTextStyle(.uiSection)
                            Text(verbatim: [next.seasonName, next.arc.name].compactMap { $0 }.joined(separator: " · "))
                                .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                            if next.plan.blocks.isEmpty {
                                Text("Este treino ainda não tem exercícios.")
                                    .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color.hts.greyApp)
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Abre o treino")
        } else {
            PlaceholderCard(label: "PRÓXIMO TREINO", text: "Nenhum arco atual.")
        }
    }

    /// Countdown to A Batalha: alert card on `blood-deep` with the tape on top.
    private func battleCard(_ battle: Battle) -> some View {
        let days = battle.daysUntil(.today)
        return VStack(alignment: .leading, spacing: 0) {
            AlertTape()
            VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                Text("A BATALHA").htsTextStyle(.label).foregroundStyle(Color.hts.redText)
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: battle.name).htsTextStyle(.uiSection)
                    Spacer()
                    Text(days == 0 ? "Hoje" : (days == 1 ? "1 dia" : "\(days) dias")).htsTextStyle(.data)
                }
                Text(verbatim: battle.date.short).htsTextStyle(.dataSm).foregroundStyle(Color.hts.greyApp)
                if battle.isEve(.today) {
                    Text("Semana da Véspera. Faça os treinos do arco especial.")
                        .htsTextStyle(.caption).foregroundStyle(Color.hts.bone)
                }
            }
            .padding(HTSSpacing.space5)
        }
        .background(Color.hts.bloodDeep)
        .overlay(Rectangle().strokeBorder(Color.hts.blood, lineWidth: HTSStroke.hair))
    }

    private func weekCard(_ model: HomeModel) -> some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                HStack {
                    Text("ESTA SEMANA").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    Spacer()
                    Text(
                        verbatim: model.weekGoal > 0
                            ? String(format: "%02d/%02d", model.weekDone, model.weekGoal)
                            : String(format: "%02d", model.weekDone)
                    )
                    .htsTextStyle(.data)
                }
                if let streak = model.streak, streak.current > 0 || streak.best > 0 {
                    HStack {
                        Text("SEQUÊNCIA").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        Spacer()
                        Text(streak.current == 1 ? "1 semana" : "\(streak.current) semanas").htsTextStyle(.dataSm)
                        if streak.best > streak.current {
                            Text(verbatim: "· melhor \(streak.best)").htsTextStyle(.dataSm)
                                .foregroundStyle(Color.hts.greyApp)
                        }
                    }
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
