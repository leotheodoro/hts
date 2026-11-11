import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// An arc and its workouts. Each workout opens the workout page, where it can be started.
struct ArcDetailScreen: View {
    let arcId: UUID
    @Environment(AppModel.self) private var app
    @State private var plan: ArcPlan?
    /// The day each treino teste was last done (#216).
    @State private var lastRuns: [UUID: LocalDate] = [:]

    var body: some View {
        DetailScaffold {
            if let plan {
                HStack(alignment: .top, spacing: HTSSpacing.space4) {
                    if let kanji = plan.arc.kanji {
                        Text(verbatim: kanji).htsTextStyle(.kanji).foregroundStyle(Color.hts.bone)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                        Text(statusLabel(plan.arc)).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        Text(verbatim: plan.arc.name).htsTextStyle(.uiTitle)
                        if let program = plan.arc.program {
                            Text(verbatim: program).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                    Text("TREINOS").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    // A treino teste is always first, with its own border (#216).
                    ForEach(
                        plan.templates.filter(\.template.isTest) + plan.templates.filter { !$0.template.isTest },
                        id: \.template.id
                    ) { template in
                        NavigationLink(value: Route.workout(templateId: template.template.id)) {
                            NotchCard(border: template.template.isTest ? Color.hts.oliveEdge : Color.hts.line) {
                                HStack(spacing: HTSSpacing.space3) {
                                    VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                                        if template.template.isTest { TestTag() }
                                        // A test is outside the rotation: no letter (#216).
                                        Text(
                                            verbatim: template.template.isTest
                                                ? template.template.name
                                                : "\(template.template.letter) · \(template.template.name)"
                                        )
                                        .htsTextStyle(.uiSection)
                                        if let focus = template.template.focus {
                                            Text(verbatim: focus).htsTextStyle(.caption)
                                                .foregroundStyle(Color.hts.greyApp)
                                        }
                                        if template.template.isTest {
                                            Text(lastRunText(template.template.id)).htsTextStyle(.caption)
                                                .foregroundStyle(Color.hts.greyApp)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(Color.hts.greyApp)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task(id: "\(arcId)-\(app.dataVersion)") {
            guard let database = app.database else { return }
            plan = try? await PlanRepository(database).plan(arcId: arcId)
            var runs: [UUID: LocalDate] = [:]
            for template in plan?.templates ?? [] where template.template.isTest {
                runs[template.template.id] =
                    try? await SessionRepository(database).testRuns(templateId: template.template.id, limit: 1)
                    .first?.date
            }
            lastRuns = runs
        }
    }

    private func lastRunText(_ templateId: UUID) -> LocalizedStringKey {
        guard let date = lastRuns[templateId] else { return "Ainda não feito" }
        return "Última vez \(EvolutionTable.day(date))"
    }

    private func statusLabel(_ arc: Arc) -> LocalizedStringKey {
        if arc.kind == .filler { return "SEMPRE DISPONÍVEL" }
        switch arc.status {
        case .current: return "ATUAL"
        case .queued: return "BLOQUEADO"
        case .completed: return "CONCLUÍDO"
        }
    }
}
