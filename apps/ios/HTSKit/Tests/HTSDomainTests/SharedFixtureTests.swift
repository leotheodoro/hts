import Foundation
import Testing

@testable import HTSDomain

/// Runs the same cases as `packages/progression/test/fixtures.test.ts`.
struct Fixture<Input: Decodable & Sendable, Expected: Decodable & Sendable>: Decodable, Sendable {
    struct Case: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let input: Input
        let expected: Expected
        var testDescription: String { name }
    }
    let function: String
    let cases: [Case]

    static func load(_ file: String) -> [Case] {
        guard let url = Bundle.module.url(forResource: file, withExtension: "json", subdirectory: "Fixtures") else {
            fatalError("Fixture \(file).json not found; run pnpm sync:shared")
        }
        do {
            return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url)).cases
        } catch {
            fatalError("Invalid fixture \(file).json: \(error)")
        }
    }
}

struct XPInput: Decodable, Sendable { let xp: Int }
struct LevelOutput: Decodable, Sendable { let level: Int }
struct LevelInput: Decodable, Sendable { let level: Int }
struct RankOutput: Decodable, Sendable { let id: String, name: String }

@Suite struct SharedFixtureTests {
    let progression = Progression()

    @Test(arguments: Fixture<XPInput, LevelOutput>.load("level-for-xp"))
    func levelForXp(_ c: Fixture<XPInput, LevelOutput>.Case) {
        #expect(progression.level(forXP: c.input.xp) == c.expected.level)
    }

    @Test(arguments: Fixture<LevelInput, RankOutput>.load("rank-for-level"))
    func rankForLevel(_ c: Fixture<LevelInput, RankOutput>.Case) {
        let rank = progression.rank(forLevel: c.input.level)
        #expect(rank.id.rawValue == c.expected.id)
        #expect(rank.name == c.expected.name)
    }

    @Test(arguments: Fixture<SessionXPInput, SessionXP>.load("xp-for-session"))
    func xpForSession(_ c: Fixture<SessionXPInput, SessionXP>.Case) {
        #expect(progression.xp(for: c.input) == c.expected)
    }

    @Test func everyFixtureFileIsCovered() throws {
        let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "Fixtures") ?? []
        let names = Set(urls.map { $0.deletingPathExtension().lastPathComponent })
        #expect(names == ["level-for-xp", "rank-for-level", "xp-for-session"])
    }
}
