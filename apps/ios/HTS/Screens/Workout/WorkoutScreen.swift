import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// Read-only workout: blocks, exercises and prescriptions, with "Iniciar treino" when it can be trained.
struct WorkoutScreen: View {
    let templateId: UUID
    @Environment(AppModel.self) private var app
    @State private var model: WorkoutModel?

    var body: some View {
        DetailScaffold {
            if let model, let plan = model.plan, let arc = model.arc {
                header(plan, arc)
                startSection(model)
                ForEach(Array(plan.blocks.enumerated()), id: \.element.block.id) { index, block in
                    blockSection(block, number: index + 1)
                }
            }
        }
        .task(id: "\(templateId)-\(app.dataVersion)") {
            guard let database = app.database else { return }
            let model = WorkoutModel(database: database, templateId: templateId)
            await model.load()
            self.model = model
        }
    }

    private func header(_ plan: TemplatePlan, _ arc: Arc) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space2) {
            Text(verbatim: [arc.kanji, arc.name.uppercased()].compactMap { $0 }.joined(separator: " · "))
                .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            Text(verbatim: "\(plan.template.letter) · \(plan.template.name)").htsTextStyle(.uiTitle)
            if let focus = plan.template.focus {
                Text(verbatim: focus).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
            }
        }
    }

    @ViewBuilder private func startSection(_ model: WorkoutModel) -> some View {
        switch model.start(hasActiveSession: app.activeSession != nil) {
        case .available:
            if let plan = model.plan {
                HTSButton("Iniciar treino") { Task { await app.startWorkout(plan) } }
            }
        case .busy:
            VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                Text("Há um treino em andamento.").htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                HTSButton("Continuar treino", kind: .ghost) { app.showsActiveSession = true }
            }
        case .locked:
            Text(model.arc?.status == .completed ? "Arco concluído." : "Arco bloqueado. Conclua o arco atual antes.")
                .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
        case .empty:
            Text("Este treino ainda não tem exercícios.").htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
        }
    }

    private func blockSection(_ block: BlockPlan, number: Int) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space3) {
            HStack(spacing: HTSSpacing.space2) {
                Text(verbatim: String(format: "%02d", number))
                Text(block.block.kind.label).textCase(.uppercase)
                Text(verbatim: block.block.attributes.map(\.abbreviation).joined(separator: " "))
                if block.block.kind == .fightRound, let minutes = block.block.durationMinutes {
                    Text(verbatim: "· \(minutes) MIN")
                }
            }
            .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            NotchCard {
                VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                    ForEach(block.exercises, id: \.prescription.id) { planned in
                        VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                            Text(verbatim: planned.exercise.name).htsTextStyle(.bodyStrong)
                            Text(verbatim: prescription(planned)).htsTextStyle(.dataSm)
                                .foregroundStyle(Color.hts.greyApp).monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private func prescription(_ planned: PlannedExercise) -> String {
        let p = planned.prescription
        var parts = [
            "\(TargetNotation.formatSets(min: p.setsMin, max: p.setsMax)) × "
                + TargetNotation.format(p.targets, unit: planned.exercise.unit, perSide: planned.exercise.perSide)
        ]
        if let rest = p.restSeconds { parts.append("desc. \(rest) s") }
        return parts.joined(separator: " · ")
    }
}
