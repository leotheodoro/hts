import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// An activity imported from Garmin: what was recorded and what it gave (spec 2026-10-31).
struct ActivityDetailSheet: View {
    let entry: ProgressService.ActivityEntry

    @Environment(\.dismiss) private var dismiss

    private var activity: ImportedActivity { entry.activity }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HTSSpacing.space6) {
                    VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                        HStack {
                            Text(activity.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                            Spacer()
                            GarminBadge()
                        }
                        Text(activity.typeLabel).htsTextStyle(.uiTitle)
                        Text(verbatim: "+\(entry.xp.xp) XP").htsTextStyle(.dataSm).foregroundStyle(Color.hts.greyApp)
                    }
                    VStack(spacing: 0) {
                        row("Duração", "\(activity.durationSeconds / 60) min")
                        if let distance = activity.distanceMeters, distance > 0 {
                            let km = NSDecimalNumber(decimal: distance).doubleValue / 1000
                            row("Distância", "\(km.formatted(.number.precision(.fractionLength(2)))) km")
                            let pace = Int((Double(activity.durationSeconds) / km).rounded())
                            row("Pace médio", String(format: "%d:%02d /km", pace / 60, pace % 60))
                        }
                        if let heartRate = activity.averageHeartRate { row("FC média", "\(heartRate) bpm") }
                        if let calories = activity.calories { row("Calorias", "\(calories) kcal") }
                    }
                    if !entry.xp.attributes.isEmpty {
                        VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                            Text("ATRIBUTOS").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                            AttributeBadges(attributes: entry.xp.attributes)
                            Text("+\(entry.xp.attributeXP) XP em cada um").htsTextStyle(.caption)
                                .foregroundStyle(Color.hts.greyApp)
                        }
                    }
                    Text("Atividades do Garmin dão XP, mas não contam para a meta da semana nem para a sequência.")
                        .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
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
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).htsTextStyle(.body).foregroundStyle(Color.hts.greyApp)
            Spacer()
            Text(verbatim: value).htsTextStyle(.data).monospacedDigit()
        }
        .padding(.vertical, HTSSpacing.space3)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hts.line).frame(height: HTSStroke.hair) }
    }
}
