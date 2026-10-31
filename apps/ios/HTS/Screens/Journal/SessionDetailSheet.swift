import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// Every set of a finished session, from its snapshot, and "Excluir treino" with an on-screen confirmation.
struct SessionDetailSheet: View {
    let model: JournalModel
    let entry: JournalModel.Entry

    @Environment(\.dismiss) private var dismiss
    @State private var sets: [UUID: [LoggedSet]] = [:]
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HTSSpacing.space7) {
                    VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                        Text(verbatim: "\(entry.session.localDate.short) · TR \(String(format: "%02d", entry.number))")
                            .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        Text(verbatim: "\(entry.session.planSnapshot.letter) · \(entry.session.planSnapshot.name)")
                            .htsTextStyle(.uiTitle)
                        Text(verbatim: "+\(entry.progress.xp) XP · \(LoggedSet.format(entry.progress.volumeKg)) kg")
                            .htsTextStyle(.dataSm).foregroundStyle(Color.hts.greyApp)
                    }
                    ForEach(model.linkedActivities[entry.session.id] ?? []) { linked($0) }
                    ForEach(entry.session.planSnapshot.blocks, id: \.blockId) { block in
                        ForEach(block.exercises, id: \.prescribedExerciseId) { exercise in
                            exerciseSets(exercise)
                        }
                    }
                    deleteSection
                }
                .foregroundStyle(Color.hts.bone)
                .padding(.horizontal, HTSSpacing.space5)
                .padding(.vertical, HTSSpacing.space4)
            }
            .background(Color.hts.black)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }.tint(Color.hts.bone)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            let all = (try? await SessionRepository(model.database).sets(sessionId: entry.session.id)) ?? []
            sets = Dictionary(grouping: all, by: \.prescribedExerciseId)
        }
    }

    /// The watch recorded this workout too: its heart rate and calories show here, with no XP of their own.
    private func linked(_ activity: ImportedActivity) -> some View {
        HStack(spacing: HTSSpacing.space5) {
            if let heartRate = activity.averageHeartRate {
                VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                    Text("FC MÉDIA").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    Text(verbatim: "\(heartRate) bpm").htsTextStyle(.data)
                }
            }
            if let calories = activity.calories {
                VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                    Text("CALORIAS").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    Text(verbatim: "\(calories) kcal").htsTextStyle(.data)
                }
            }
            Spacer()
            GarminBadge()
        }
    }

    @ViewBuilder private func exerciseSets(_ exercise: PlanSnapshot.Exercise) -> some View {
        let rows = (sets[exercise.prescribedExerciseId] ?? []).sorted { $0.setNumber < $1.setNumber }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                Text(verbatim: exercise.name).htsTextStyle(.uiSection)
                ForEach(rows) { set in
                    HStack {
                        Text(verbatim: String(format: "%02d", set.setNumber)).htsTextStyle(.dataSm)
                            .frame(width: 32, alignment: .leading)
                        Text(verbatim: set.summary(unit: exercise.unit) ?? "—").htsTextStyle(.dataSm)
                        Spacer()
                        if !set.completed {
                            Text("não marcada").htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                        }
                    }
                    .foregroundStyle(set.completed ? Color.hts.bone : Color.hts.greyApp)
                }
            }
        }
    }

    @ViewBuilder private var deleteSection: some View {
        if confirmingDelete {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Text("Excluir este treino?").htsTextStyle(.bodyStrong).foregroundStyle(Color.hts.redText)
                Text("XP, recordes e sequência são recalculados sem ele.")
                    .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                HTSButton("Excluir treino") {
                    Task {
                        await model.delete(entry.session)
                        dismiss()
                    }
                }
                HTSButton("Manter treino", kind: .ghost) { confirmingDelete = false }
            }
            .padding(HTSSpacing.space5)
            .background(Color.hts.bloodDeep, in: NotchShape())
            .overlay(NotchShape().strokeBorder(Color.hts.blood, lineWidth: HTSStroke.hair))
        } else {
            HTSButton("Excluir treino", kind: .ghost) { confirmingDelete = true }
        }
    }
}
