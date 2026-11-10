import Foundation
import HTSDomain
import Testing

@testable import HTS

@MainActor
@Suite struct EvolutionModelTests {
    let now = Date(timeIntervalSince1970: 1_794_142_800)

    func evolution(_ name: String, _ workouts: [(daysAgo: Double, kg: Decimal, reps: Int)]) -> ExerciseEvolution {
        ExerciseEvolution(
            exerciseId: UUID(), name: name,
            workouts: workouts.compactMap {
                .init(date: now.addingTimeInterval(-$0.daysAgo * 86_400), sets: [.init(weightKg: $0.kg, reps: $0.reps)])
            })
    }

    /// What rose most in the month first; exercises with nothing a month ago after them, by name.
    @Test func theListStartsWithWhatRoseMost() {
        let ordered = EvolutionModel.ordered(
            [
                evolution("Supino", [(40, 60, 8), (0, 60, 8)]),
                evolution("Terra", [(40, 110, 3), (0, 120, 4)]),
                evolution("Afundo", [(5, 20, 10)]),
                evolution("Agachamento", [(3, 80, 5)]),
                evolution("Zercher", [(40, 70, 5), (0, 70, 6)]),
            ], now: now)
        #expect(ordered.map(\.name) == ["Terra", "Zercher", "Supino", "Afundo", "Agachamento"])
    }

    @Test func theSentenceSaysWhatChangedInTheMonth() {
        let s = EvolutionModel.sentence
        #expect(s(.init(kg: 10, reps: 1)) == "+10 kg e uma repetição a mais em um mês.")
        #expect(s(.init(kg: 0, reps: 2)) == "2 repetições a mais em um mês.")
        #expect(s(.init(kg: Decimal(string: "2.5")!, reps: 0)) == "+2,5 kg em um mês.")
        #expect(s(.init(kg: -5, reps: 3)) == "5 kg a menos e 3 repetições a mais em um mês.")
        #expect(s(.init(kg: 0, reps: 0)) == "A mesma série de um mês atrás.")
    }

    /// "+43 kg (+46%)" since the first workout: 80 × 5 then, 120 × 4 now.
    @Test func sinceTheStartComparesTheBestWithTheFirst() throws {
        let terra = evolution("Terra", [(100, 80, 5), (0, 120, 4)])
        let gain = try #require(EvolutionModel.sinceStart(terra))
        #expect(gain.kg == 43)
        #expect(gain.percent == 46)
    }
}
