import Foundation
import Testing

@testable import HTSDomain

struct NameInput: Decodable, Sendable { let name: String }
struct NameOutput: Decodable, Sendable { let normalized: String }

@Suite struct ExerciseNameTests {
    @Test(arguments: Fixture<NameInput, NameOutput>.load("normalize-exercise-name"))
    func normalizeExerciseName(_ c: Fixture<NameInput, NameOutput>.Case) {
        #expect(ExerciseName.normalize(c.input.name) == c.expected.normalized)
    }
}

@Suite struct SetTargetTests {
    @Test func encodesLikeTheAPI() throws {
        let targets: [SetTarget] = [.fixed(6), .range(min: 10, max: 20), .max]
        let json = String(decoding: try JSONEncoder.sorted.encode(targets), as: UTF8.self)
        #expect(json == #"[{"type":"fixed","value":6},{"max":20,"min":10,"type":"range"},{"type":"max"}]"#)
        #expect(try JSONDecoder().decode([SetTarget].self, from: Data(json.utf8)) == targets)
    }

    @Test func fitsOneTargetForAllSetsOrOnePerSet() {
        #expect([SetTarget.fixed(8)].fits(setsMax: 3))
        #expect([SetTarget](repeating: .fixed(6), count: 4).fits(setsMax: 4))
        #expect(![SetTarget](repeating: .fixed(6), count: 2).fits(setsMax: 4))
        #expect(![SetTarget.range(min: 20, max: 10)].fits(setsMax: 1))
        #expect(![SetTarget]().fits(setsMax: 1))
    }

    @Test func resolvesTheTargetOfEachSet() {
        let perSet: [SetTarget] = [.fixed(6), .fixed(6), .fixed(3), .fixed(3)]
        #expect(perSet.target(forSet: 2) == .fixed(3))
        #expect([SetTarget.fixed(8)].target(forSet: 3) == .fixed(8))
        #expect(perSet.target(forSet: 4) == nil)
    }
}

@Suite struct LocalDateTests {
    @Test func parsesAndFormatsISODates() throws {
        let date = try #require(LocalDate("2026-11-02"))
        #expect(date.description == "2026-11-02")
        #expect(LocalDate("2026-02-30") == nil)
        #expect(LocalDate("2026-2-3") == nil)
        #expect(LocalDate(year: 2028, month: 2, day: 29) != nil)
    }
}

extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }
}
