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
                if let evolution = model.evolution { EvolutionTable(evolution: evolution) }
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
            HStack(spacing: HTSSpacing.space2) {
                Text(verbatim: [arc.kanji, arc.name.uppercased()].compactMap { $0 }.joined(separator: " · "))
                    .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                if plan.template.isTest { TestTag() }
            }
            Text(
                verbatim: plan.template.isTest
                    ? plan.template.name : "\(plan.template.letter) · \(plan.template.name)"
            ).htsTextStyle(.uiTitle)
            if let focus = plan.template.focus {
                Text(verbatim: focus).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
            }
        }
    }

    @ViewBuilder private func startSection(_ model: WorkoutModel) -> some View {
        switch model.start(hasActiveSession: app.activeSession != nil) {
        case .available:
            if let plan = model.plan {
                HTSButton(plan.template.isTest ? "Iniciar teste" : "Iniciar treino") {
                    Task { await app.startWorkout(plan) }
                }
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
                Group {
                    Text(verbatim: String(format: "%02d", number))
                    Text(block.block.kind.label).textCase(.uppercase)
                    if block.block.kind == .fightRound, let minutes = block.block.durationMinutes {
                        Text(verbatim: "· \(minutes) MIN")
                    }
                }
                .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                AttributeBadges(attributes: block.block.attributes)
            }
            NotchCard {
                VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                    ForEach(block.exercises, id: \.prescription.id) { planned in
                        HStack(alignment: .center, spacing: HTSSpacing.space2) {
                            VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                                Text(verbatim: planned.exercise.name).htsTextStyle(.bodyStrong)
                                Text(verbatim: prescription(planned)).htsTextStyle(.dataSm)
                                    .foregroundStyle(Color.hts.greyApp).monospacedDigit()
                                if let notes = planned.prescription.notes { ExerciseNotes(text: notes) }
                            }
                            Spacer(minLength: 0)
                            if let video = planned.exercise.video {
                                VideoButton(url: video, exerciseName: planned.exercise.name)
                                    .padding(.vertical, -HTSSpacing.space3)
                            }
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

/// EVOLUÇÃO of a treino teste (#216): the run before and the last one, side by side, with the difference. Better in
/// `redText` (a record), worse in grey.
struct EvolutionTable: View {
    let evolution: TestEvolution

    var body: some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space3) {
            Text("EVOLUÇÃO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            NotchCard {
                Grid(alignment: .trailing, horizontalSpacing: HTSSpacing.space3, verticalSpacing: HTSSpacing.space3) {
                    GridRow {
                        Text("EXERCÍCIO").gridColumnAlignment(.leading)
                        if let previous = evolution.previousDate { Text(verbatim: Self.day(previous)) }
                        Text(verbatim: Self.day(evolution.latestDate))
                        if evolution.previousDate != nil { Color.clear.frame(width: 1, height: 1) }
                    }
                    .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    ForEach(evolution.rows, id: \.name) { row in
                        GridRow {
                            Text(verbatim: row.name).htsTextStyle(.body).foregroundStyle(Color.hts.bone)
                                .multilineTextAlignment(.leading)
                            if evolution.previousDate != nil { value(row.previous, color: Color.hts.greyApp) }
                            value(row.latest, color: Color.hts.bone)
                            if evolution.previousDate != nil {
                                value(row.delta, color: row.trend == .better ? Color.hts.redText : Color.hts.grey)
                            }
                        }
                    }
                }
            }
        }
    }

    private func value(_ text: String?, color: Color) -> some View {
        Text(verbatim: text ?? "—").htsTextStyle(.dataSm).monospacedDigit().foregroundStyle(color)
    }

    /// "14 set".
    static func day(_ date: LocalDate) -> String {
        guard let value = Calendar.current.date(from: DateComponents(year: date.year, month: date.month, day: date.day))
        else { return date.description }
        return value.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "pt_BR")))
            .replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " de ", with: " ")
    }
}

/// TESTE: the tag of a treino teste (#216).
struct TestTag: View {
    var body: some View {
        Text("TESTE").htsTextStyle(.label).foregroundStyle(Color.hts.oliveInk)
            .padding(.horizontal, HTSSpacing.space2).padding(.vertical, HTSSpacing.space1)
            .background(Color.hts.olive)
    }
}
