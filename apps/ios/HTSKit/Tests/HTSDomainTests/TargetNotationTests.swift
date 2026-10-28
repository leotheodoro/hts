import Testing

@testable import HTSDomain

@Suite struct TargetNotationTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let typed: String
        let setsMax: Int
        let unit: ExerciseUnit
        let targets: [SetTarget]
        let perSide: Bool
        let shown: String
        var testDescription: String { typed }
    }

    static let cases: [Case] = [
        .init(typed: "8", setsMax: 3, unit: .reps, targets: [.fixed(8)], perSide: false, shown: "8"),
        .init(
            typed: "6-6-3-3", setsMax: 4, unit: .reps, targets: [.fixed(6), .fixed(6), .fixed(3), .fixed(3)],
            perSide: false, shown: "6-6-3-3"),
        .init(typed: "12/12", setsMax: 3, unit: .reps, targets: [.fixed(12)], perSide: true, shown: "12/12"),
        .init(
            typed: "10-20 s", setsMax: 3, unit: .seconds, targets: [.range(min: 10, max: 20)], perSide: false,
            shown: "10-20 s"),
        .init(typed: "máx", setsMax: 3, unit: .reps, targets: [.max], perSide: false, shown: "máx"),
        .init(typed: "MAX", setsMax: 1, unit: .reps, targets: [.max], perSide: false, shown: "máx"),
        .init(typed: "1,5 min", setsMax: 2, unit: .minutes, targets: [.fixed(1.5)], perSide: false, shown: "1,5 min"),
        .init(typed: "400 m", setsMax: 4, unit: .meters, targets: [.fixed(400)], perSide: false, shown: "400 m"),
    ]

    @Test(arguments: cases)
    func readsAndShowsEveryFormat(_ c: Case) throws {
        let parsed = try #require(TargetNotation.parse(c.typed, setsMax: c.setsMax))
        #expect(parsed.targets == c.targets)
        #expect(parsed.perSide == c.perSide)
        #expect(TargetNotation.format(parsed.targets, unit: c.unit, perSide: parsed.perSide) == c.shown)
        // What is shown reads back to the same targets.
        #expect(TargetNotation.parse(c.shown, setsMax: c.setsMax)?.targets == c.targets)
    }

    @Test func rejectsInvalidTargets() {
        #expect(TargetNotation.parse("6-6-3", setsMax: 4) == nil)
        #expect(TargetNotation.parse("abc", setsMax: 3) == nil)
        #expect(TargetNotation.parse("0", setsMax: 3) == nil)
        #expect(TargetNotation.parse("12/10", setsMax: 3) == nil)
        #expect(TargetNotation.parse("", setsMax: 3) == nil)
    }

    @Test func twoNumbersArePerSetWhenThereAreTwoSets() {
        #expect(TargetNotation.parse("8-10", setsMax: 2)?.targets == [.fixed(8), .fixed(10)])
        #expect(TargetNotation.parse("8-10", setsMax: 3)?.targets == [.range(min: 8, max: 10)])
    }

    @Test func readsSetRanges() {
        #expect(TargetNotation.parseSets("3") == .init(min: 3, max: 3))
        #expect(TargetNotation.parseSets("3 a 4") == .init(min: 3, max: 4))
        #expect(TargetNotation.parseSets("3-4") == .init(min: 3, max: 4))
        #expect(TargetNotation.parseSets("4-3") == nil)
        #expect(TargetNotation.formatSets(min: 3, max: 4) == "3 a 4")
    }
}

@Suite struct LoadGuideTests {
    @Test func followsTheRepRanges() {
        #expect(LoadGuide.hint(for: [.fixed(3)], unit: .reps) == .maximal)
        #expect(LoadGuide.hint(for: [.fixed(6), .fixed(6), .fixed(3), .fixed(3)], unit: .reps) == .heavy)
        #expect(LoadGuide.hint(for: [.range(min: 8, max: 12)], unit: .reps) == .moderate)
        #expect(LoadGuide.hint(for: [.fixed(15)], unit: .reps) == .light)
        #expect(LoadGuide.hint(for: [.max], unit: .reps) == nil)
        #expect(LoadGuide.hint(for: [.fixed(30)], unit: .seconds) == nil)
        #expect(LoadGuide.heavy.label == "70 a 85% RM")
    }
}
