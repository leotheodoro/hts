import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// An arc and its workouts. Each workout opens the workout page, where it can be started.
struct ArcDetailScreen: View {
    let arcId: UUID
    @Environment(AppModel.self) private var app
    @State private var plan: ArcPlan?

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
                    ForEach(plan.templates, id: \.template.id) { template in
                        NavigationLink(value: Route.workout(templateId: template.template.id)) {
                            NotchCard {
                                HStack(spacing: HTSSpacing.space3) {
                                    VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                                        Text(verbatim: "\(template.template.letter) · \(template.template.name)")
                                            .htsTextStyle(.uiSection)
                                        if let focus = template.template.focus {
                                            Text(verbatim: focus).htsTextStyle(.caption)
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
        }
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
