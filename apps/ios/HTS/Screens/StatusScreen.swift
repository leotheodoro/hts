import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

struct StatusScreen: View {
    @Environment(AppModel.self) private var app
    @State private var next: NextWorkout?

    /// The template to do next in the current arc.
    struct NextWorkout {
        let arc: Arc
        let plan: TemplatePlan
        let position: Int
        let total: Int?
    }

    var body: some View {
        ScreenScaffold(title: "Status") {
            if app.activeSession != nil {
                NotchCard {
                    VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                        Text("TREINO EM ANDAMENTO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        if let snapshot = app.activeSession?.planSnapshot {
                            Text(verbatim: "\(snapshot.letter) · \(snapshot.name)").htsTextStyle(.uiSection)
                        }
                        HTSButton("Continuar") { app.showsActiveSession = true }
                    }
                }
            } else if let next {
                NotchCard {
                    VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                        Text(nextLabel(next)).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        Text(verbatim: "\(next.plan.template.letter) · \(next.plan.template.name)")
                            .htsTextStyle(.uiSection)
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
        .task(id: app.activeSession?.id) { await loadNext() }
    }

    private func nextLabel(_ next: NextWorkout) -> LocalizedStringKey {
        guard let total = next.total else { return "PRÓXIMO TREINO" }
        return "PRÓXIMO TREINO · \(String(format: "%02d/%02d", next.position, total))"
    }

    private func loadNext() async {
        guard let database = app.database, let athlete = app.athlete else { return }
        let plans = PlanRepository(database)
        guard let arc = try? await plans.currentArc(athleteId: athlete.id),
            let plan = try? await plans.plan(arcId: arc.id)
        else {
            next = nil
            return
        }
        let schedule = ArcSchedule(plan)
        let last = try? await SessionRepository(database).lastLetter(arcId: arc.id)
        guard let letter = schedule.next(after: last),
            let template = plan.templates.first(where: { $0.template.letter == letter })
        else {
            next = nil
            return
        }
        let done =
            (try? await ArcService(database).summaries(athleteId: athlete.id, sagaId: arc.sagaId))?
            .first { $0.arc.id == arc.id }?.completedSessions ?? 0
        next = NextWorkout(arc: arc, plan: template, position: done + 1, total: schedule.totalSessions)
    }
}
