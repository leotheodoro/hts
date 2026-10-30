import HTSDesign
import HTSDomain
import SwiftUI
import UIKit

/// Round de Luta: a timed block without pauses. Counts complete rounds and the load per exercise.
struct FightRoundSection: View {
    let model: ActiveSessionModel
    let block: PlanSnapshot.Block

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space4) {
                timer
                counter
                ForEach(block.exercises, id: \.prescribedExerciseId) { exercise in
                    HStack(spacing: HTSSpacing.space3) {
                        VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                            Text(verbatim: exercise.name).htsTextStyle(.bodyStrong).foregroundStyle(Color.hts.bone)
                            Text(
                                verbatim: TargetNotation.format(
                                    exercise.targets, unit: exercise.unit, perSide: exercise.perSide)
                            )
                            .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                        }
                        Spacer()
                        NumberField(
                            value: model.roundWeight(exercise: exercise, block: block), prompt: "kg",
                            keyboard: .decimalPad
                        ) { model.setRoundWeight($0, exercise: exercise, block: block) }
                        .frame(width: 80)
                    }
                }
            }
        }
    }

    @ViewBuilder private var timer: some View {
        let duration = (block.durationMinutes ?? 8) * 60
        if let running = model.roundTimers[block.blockId] {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                    HStack {
                        FieldLabel(text: "ROUND")
                        Spacer()
                        Text(verbatim: RestTimer.format(running.remaining(at: context.date)))
                            .htsTextStyle(.uiDisplay).foregroundStyle(Color.hts.bone)
                    }
                    ProgressBar(value: running.progress(at: context.date))
                    HTSButton("Parar round", kind: .ghost) { model.stopRoundTimer(block) }
                }
                .onChange(of: running.isFinished(at: context.date)) { _, finished in
                    guard finished else { return }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    model.stopRoundTimer(block)
                }
            }
        } else {
            HStack {
                FieldLabel(text: "ROUND")
                Spacer()
                Text(verbatim: RestTimer.format(TimeInterval(duration))).htsTextStyle(.uiDisplay)
                    .foregroundStyle(Color.hts.greyApp)
            }
            HTSButton("Iniciar round", kind: .ghost) { model.startRoundTimer(block) }
        }
    }

    private var counter: some View {
        let count = model.rounds[block.blockId]?.roundsCompleted ?? 0
        return HStack(spacing: HTSSpacing.space3) {
            FieldLabel(text: "ROUNDS COMPLETOS")
            Spacer()
            IconButton(symbol: "minus", label: "Tirar um round") {
                model.setRoundsCompleted(count - 1, block: block)
            }
            Text(verbatim: String(format: "%02d", count)).htsTextStyle(.data).foregroundStyle(Color.hts.bone)
            IconButton(symbol: "plus", label: "Somar um round") {
                model.setRoundsCompleted(count + 1, block: block)
            }
        }
    }
}
