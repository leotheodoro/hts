import Foundation
import HTSDomain
import HTSPersistence
import Observation

/// Perfil > Evolução (#202): every lift with its estimated max and how it moved over the last month.
@MainActor
@Observable
final class EvolutionModel {
    struct SinceStart: Hashable {
        /// Best estimated max minus the first workout's, rounded.
        let kg: Int
        let percent: Int
    }

    private(set) var exercises: [ExerciseEvolution] = []
    private(set) var loaded = false

    private let database: AppDatabase
    private let athleteId: UUID

    init(database: AppDatabase, athleteId: UUID) {
        self.database = database
        self.athleteId = athleteId
    }

    func load(now: Date = .now) async {
        let all = (try? await ProgressService(database).evolution(athleteId: athleteId)) ?? []
        exercises = Self.ordered(all, now: now)
        loaded = true
    }

    func exercise(_ id: UUID) -> ExerciseEvolution? { exercises.first { $0.exerciseId == id } }

    /// What rose most in the month first; exercises with nothing a month ago after them, by name.
    static func ordered(_ all: [ExerciseEvolution], now: Date) -> [ExerciseEvolution] {
        all.sorted { a, b in
            switch (a.change(now: now), b.change(now: now)) {
            case (let x?, let y?) where x != y: x > y
            case (.some, nil): true
            case (nil, .some): false
            default: a.name < b.name
            }
        }
    }

    /// "+10 kg e uma repetição a mais em um mês."
    static func sentence(_ gain: ExerciseEvolution.Gain) -> String {
        var parts: [String] = []
        if gain.kg > 0 { parts.append("+\(LoggedSet.format(gain.kg)) kg") }
        if gain.kg < 0 { parts.append("\(LoggedSet.format(-gain.kg)) kg a menos") }
        switch gain.reps {
        case 1: parts.append("uma repetição a mais")
        case -1: parts.append("uma repetição a menos")
        case let reps where reps > 1: parts.append("\(reps) repetições a mais")
        case let reps where reps < -1: parts.append("\(-reps) repetições a menos")
        default: break
        }
        guard !parts.isEmpty else { return String(localized: "A mesma série de um mês atrás.") }
        return parts.joined(separator: " e ") + " em um mês."
    }

    static func sinceStart(_ exercise: ExerciseEvolution) -> SinceStart? {
        guard let first = exercise.first?.estimatedMax, let best = exercise.bestEstimatedMax?.estimatedMax,
            first > 0
        else { return nil }
        let gain = NSDecimalNumber(decimal: best - first).doubleValue
        let base = NSDecimalNumber(decimal: first).doubleValue
        return SinceStart(kg: Int(gain.rounded()), percent: Int((gain / base * 100).rounded()))
    }
}

extension Decimal {
    /// Whole kilos for the estimated max: "136".
    var wholeKg: String { "\(Int(NSDecimalNumber(decimal: self).doubleValue.rounded()))" }
}
