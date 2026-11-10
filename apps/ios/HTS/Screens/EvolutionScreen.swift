import Charts
import HTSDesign
import HTSDomain
import HTSPersistence
import SwiftUI

/// Perfil > Evolução (#202): each lift with its estimated max and the change over the last 30 days.
struct EvolutionScreen: View {
    @Environment(AppModel.self) private var app
    @State private var model: EvolutionModel?

    var body: some View {
        DetailScaffold {
            Text("Evolução").htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
            if let model, model.loaded {
                if model.exercises.isEmpty {
                    PlaceholderCard(
                        label: "EVOLUÇÃO", text: "Conclua séries com kg e repetições para ver sua evolução.")
                } else {
                    VStack(alignment: .leading, spacing: HTSSpacing.space2) {
                        Text("RM ESTIMADO · ÚLTIMOS 30 DIAS").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                        NotchCard {
                            VStack(spacing: 0) {
                                ForEach(Array(model.exercises.enumerated()), id: \.element.id) { index, exercise in
                                    if index > 0 { Rectangle().fill(Color.hts.track).frame(height: HTSStroke.hair) }
                                    row(exercise)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task(id: "\(app.athlete?.id.uuidString ?? "")-\(app.dataVersion)") {
            guard let database = app.database, let athlete = app.athlete else { return }
            let model = self.model ?? EvolutionModel(database: database, athleteId: athlete.id)
            await model.load()
            self.model = model
        }
    }

    private func row(_ exercise: ExerciseEvolution) -> some View {
        NavigationLink(value: Route.exerciseEvolution(exercise.exerciseId)) {
            HStack(spacing: HTSSpacing.space3) {
                VStack(alignment: .leading, spacing: HTSSpacing.space1) {
                    Text(verbatim: exercise.name).htsTextStyle(.bodyStrong).foregroundStyle(Color.hts.bone)
                    if let best = exercise.latest?.best {
                        Text("Último treino \(best.plate)").htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: HTSSpacing.space1) {
                    Text(verbatim: "\(exercise.latest?.estimatedMax.wholeKg ?? "—") kg").htsTextStyle(.data)
                        .monospacedDigit().foregroundStyle(Color.hts.bone)
                    ChangeLabel(change: exercise.change(now: .now))
                }
                Image(systemName: "chevron.right").foregroundStyle(Color.hts.greyApp).accessibilityHidden(true)
            }
            .padding(.vertical, HTSSpacing.space3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// "+15", "=" or "novo" next to an estimated max.
struct ChangeLabel: View {
    let change: Decimal?

    var body: some View {
        Group {
            if let change {
                let whole = Int(NSDecimalNumber(decimal: change).doubleValue.rounded())
                Text(verbatim: whole > 0 ? "+\(whole)" : (whole < 0 ? "\(whole)" : "="))
                    .foregroundStyle(whole > 0 ? Color.hts.bone : Color.hts.greyApp)
            } else {
                Text("novo").foregroundStyle(Color.hts.greyApp)
            }
        }
        .htsTextStyle(.dataSm).monospacedDigit()
    }
}

extension ExerciseEvolution.Lift {
    /// "4 × 120 kg"
    var plate: String { "\(reps) × \(LoggedSet.format(weightKg)) kg" }
}

/// One lift (#202): estimated max and its chart, a month ago against today, and since the first workout.
struct ExerciseEvolutionScreen: View {
    let exerciseId: UUID

    enum Period: String, CaseIterable, Identifiable {
        case month = "1M", quarter = "3M", all = "TUDO"
        var id: String { rawValue }
        var days: Double? {
            switch self {
            case .month: 30
            case .quarter: 90
            case .all: nil
            }
        }
    }

    @Environment(AppModel.self) private var app
    @State private var model: EvolutionModel?
    @State private var period: Period = .quarter

    var body: some View {
        DetailScaffold {
            if let exercise = model?.exercise(exerciseId) {
                Text(verbatim: exercise.name).htsTextStyle(.uiTitle).foregroundStyle(Color.hts.bone)
                maxCard(exercise)
                monthCard(exercise)
                startCard(exercise)
            }
        }
        .task(id: "\(app.athlete?.id.uuidString ?? "")-\(app.dataVersion)") {
            guard let database = app.database, let athlete = app.athlete else { return }
            let model = self.model ?? EvolutionModel(database: database, athleteId: athlete.id)
            await model.load()
            self.model = model
        }
    }

    private func maxCard(_ exercise: ExerciseEvolution) -> some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Text("RM ESTIMADO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                HStack(alignment: .firstTextBaseline, spacing: HTSSpacing.space2) {
                    Text(verbatim: exercise.latest?.estimatedMax.wholeKg ?? "—").htsTextStyle(.uiDisplay)
                        .monospacedDigit()
                    Text(verbatim: "kg").htsTextStyle(.data)
                    Spacer()
                    if let change = exercise.change(now: .now) {
                        let whole = Int(NSDecimalNumber(decimal: change).doubleValue.rounded())
                        Text("\(whole > 0 ? "+" : "")\(whole) em 30 dias").htsTextStyle(.dataSm).monospacedDigit()
                    } else {
                        Text("Novo este mês").htsTextStyle(.dataSm).foregroundStyle(Color.hts.greyApp)
                    }
                }
                periodPicker
                chart(exercise).frame(height: 160)
            }
        }
    }

    private var periodPicker: some View {
        HStack(spacing: HTSSpacing.space2) {
            ForEach(Period.allCases) { option in
                Button {
                    period = option
                } label: {
                    Text(verbatim: option.rawValue).htsTextStyle(.label)
                        .padding(.horizontal, HTSSpacing.space3).frame(minHeight: 32)
                        .foregroundStyle(period == option ? Color.hts.bone : Color.hts.grey)
                        .overlay(
                            Rectangle().strokeBorder(
                                period == option ? Color.hts.bone : Color.hts.lineStrong, lineWidth: HTSStroke.hair))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(period == option ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private func chart(_ exercise: ExerciseEvolution) -> some View {
        let from = period.days.map { Date.now.addingTimeInterval(-$0 * 86_400) }
        let points = exercise.workouts.filter { workout in from.map { workout.date >= $0 } ?? true }
        if points.count < 2 {
            Text("Com mais de um treino neste período, a linha da sua evolução aparece aqui.")
                .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        } else {
            EvolutionChart(workouts: points)
        }
    }

    @ViewBuilder private func monthCard(_ exercise: ExerciseEvolution) -> some View {
        if let then = exercise.monthAgo(now: .now), let today = exercise.latest {
            NotchCard {
                VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                    Text("HÁ 1 MÊS E HOJE").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                    HStack(spacing: HTSSpacing.space3) {
                        liftBox(then)
                        Image(systemName: "arrow.right").foregroundStyle(Color.hts.greyApp).accessibilityHidden(true)
                        liftBox(today)
                    }
                    Text(verbatim: EvolutionModel.sentence(today.best.gain(over: then.best)))
                        .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                }
            }
        }
    }

    private func liftBox(_ workout: ExerciseEvolution.Workout) -> some View {
        VStack(alignment: .leading, spacing: HTSSpacing.space1) {
            Text(verbatim: workout.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits)))
                .htsTextStyle(.label).foregroundStyle(Color.hts.grey)
            Text(verbatim: "\(workout.best.reps) × \(LoggedSet.format(workout.best.weightKg))").htsTextStyle(.data)
                .monospacedDigit()
            Text("RM \(workout.estimatedMax.wholeKg)").htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
        }
        .padding(HTSSpacing.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hts.black)
    }

    private func startCard(_ exercise: ExerciseEvolution) -> some View {
        NotchCard {
            VStack(alignment: .leading, spacing: HTSSpacing.space3) {
                Text("DESDE O COMEÇO").htsTextStyle(.label).foregroundStyle(Color.hts.grey)
                if let first = exercise.first {
                    fact("Primeiro registro · \(short(first.date))", first.best.plate)
                }
                if let heaviest = exercise.heaviest {
                    fact(
                        "Maior peso · \(short(heaviest.date))", "\(LoggedSet.format(heaviest.heaviestKg)) kg", red: true
                    )
                }
                if let best = exercise.bestEstimatedMax {
                    fact("Melhor RM · \(short(best.date))", "\(best.estimatedMax.wholeKg) kg")
                }
                if exercise.workouts.count > 1, let since = EvolutionModel.sinceStart(exercise), since.kg > 0 {
                    Text("Seu RM subiu \(since.kg) kg (+\(since.percent)%) desde o primeiro treino.")
                        .htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
                }
            }
        }
    }

    private func fact(_ label: LocalizedStringKey, _ value: String, red: Bool = false) -> some View {
        HStack {
            Text(label).htsTextStyle(.caption).foregroundStyle(Color.hts.greyApp)
            Spacer()
            Text(verbatim: value).htsTextStyle(.dataSm).monospacedDigit()
                .foregroundStyle(red ? Color.hts.redText : Color.hts.bone)
        }
    }

    private func short(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))
    }
}

/// The best estimated max of each workout over time (#202).
struct EvolutionChart: View {
    let workouts: [ExerciseEvolution.Workout]

    var body: some View {
        Chart(workouts, id: \.date) { workout in
            let value = NSDecimalNumber(decimal: workout.estimatedMax).doubleValue
            LineMark(x: .value("Data", workout.date), y: .value("RM", value))
                .foregroundStyle(Color.hts.bone)
                .lineStyle(StrokeStyle(lineWidth: HTSStroke.rule))
            PointMark(x: .value("Data", workout.date), y: .value("RM", value))
                .foregroundStyle(Color.hts.bone)
                .symbolSize(24)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.hts.track)
                AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Color.hts.grey)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.hts.track)
                AxisValueLabel().foregroundStyle(Color.hts.grey)
            }
        }
        .accessibilityLabel(Text("Gráfico do RM estimado"))
    }
}
