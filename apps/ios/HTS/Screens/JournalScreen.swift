import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

struct JournalScreen: View {
    @Environment(AppModel.self) private var app
    @State private var model: JournalModel?
    @State private var selected: JournalModel.Entry?

    var body: some View {
        ScreenScaffold(title: "Diário") {
            if let model {
                totals(model)
                if !model.records.isEmpty { records(model) }
                sessions(model)
            }
        }
        .task(
            id: "\(app.athlete?.id.uuidString ?? "")-\(app.activeSession?.id.uuidString ?? "none")-\(app.dataVersion)"
        ) {
            guard let database = app.database, let athlete = app.athlete else { return }
            let model = self.model ?? JournalModel(database: database, athleteId: athlete.id)
            await model.load()
            self.model = model
        }
        .sheet(item: $selected) { entry in
            if let model {
                SessionDetailSheet(model: model, entry: entry)
            }
        }
    }

    private func totals(_ model: JournalModel) -> some View {
        HStack(alignment: .top, spacing: HTSSpacing.space4) {
            total("TREINOS", String(format: "%02d", model.entries.count))
            total("SÉRIES", String(format: "%02d", model.totalSets))
            total("VOLUME", "\(LoggedSet.format(model.totalVolume.rounded(0))) kg")
        }
    }

    private func total(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space1) {
            Text(label).htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            Text(verbatim: value).htsTextStyle(.data).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func records(_ model: JournalModel) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space3) {
            Text("RECORDES").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            ForEach(model.records) { record in
                DogTag(lines: [
                    record.exerciseName.uppercased(),
                    LoggedSet.plate(kg: record.weightKg, reps: record.reps),
                    record.date.short,
                ])
            }
        }
    }

    @ViewBuilder private func sessions(_ model: JournalModel) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space3) {
            Text("TREINOS").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            if model.entries.isEmpty {
                Text("Os treinos concluídos aparecem aqui.").htsTextStyle(.body).foregroundStyle(Color.hts.greyApp)
            }
            ForEach(model.entries) { entry in
                Button {
                    selected = entry
                } label: {
                    SessionRow(entry: entry)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SessionRow: View {
    let entry: JournalModel.Entry

    var body: some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                HStack {
                    Text(verbatim: "\(entry.session.localDate.short) · TR \(String(format: "%02d", entry.number))")
                        .htsTextStyle(.dataSm).foregroundStyle(Color.hts.grey)
                    Spacer()
                    Text(verbatim: "+\(entry.progress.xp) XP").htsTextStyle(.dataSm)
                }
                Text(verbatim: "\(entry.session.planSnapshot.letter) · \(entry.session.planSnapshot.name)")
                    .htsTextStyle(.uiSection)
                Text(summary).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var summary: LocalizedStringKey {
        let minutes = Int((entry.session.duration ?? 0) / 60)
        let records = entry.progress.records.count
        let volume = LoggedSet.format(entry.progress.volumeKg)
        return records > 0
            ? "\(entry.progress.completedSets) séries · \(volume) kg · \(minutes) min · \(records) recordes"
            : "\(entry.progress.completedSets) séries · \(volume) kg · \(minutes) min"
    }
}

extension Decimal {
    /// Rounded to `scale` decimal places, half up.
    func rounded(_ scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
