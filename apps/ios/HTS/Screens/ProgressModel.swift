import Foundation
import HTSDomain
import HTSPersistence
import Observation

/// The Progresso page (#195): where the athlete is, the ranks ahead up to S, and the attributes against 30 days ago.
@MainActor
@Observable
final class ProgressModel {
    enum RankState: Hashable {
        case reached
        case current
        /// The rank after the current one, with the XP still missing to reach it.
        case next(xpMissing: Int)
        case locked
    }

    struct Step: Hashable, Identifiable {
        let rank: Rank
        let state: RankState
        var id: RankID { rank.id }
    }

    struct AttributeRow: Hashable, Identifiable {
        let attribute: Attribute
        let level: Int
        /// Level 30 days ago.
        let levelBefore: Int
        /// Where the XP sits inside the current level, for the bar.
        let fraction: Double
        var change: Int { level - levelBefore }
        var id: Attribute { attribute }
    }

    static let window: TimeInterval = 30 * 86_400

    private(set) var history: ProgressHistory?
    private(set) var ladder: [Step] = []
    private(set) var attributes: [AttributeRow] = []

    private let database: AppDatabase
    private let athleteId: UUID

    init(database: AppDatabase, athleteId: UUID) {
        self.database = database
        self.athleteId = athleteId
    }

    var levelProgress: Progression.LevelProgress? {
        history.map { Progression().levelProgress(xp: $0.totalXp) }
    }

    func load(now: Date = .now) async {
        let service = ProgressService(database)
        history = try? await service.history(athleteId: athleteId).history
        ladder = Self.ladder(totalXp: history?.totalXp ?? 0)
        let current = (try? await service.attributeLevels(athleteId: athleteId)) ?? [:]
        let before = (try? await service.attributeLevels(athleteId: athleteId, asOf: now - Self.window)) ?? [:]
        attributes = Self.attributeRows(now: current, before: before)
    }

    static func ladder(totalXp: Int, progression: Progression = Progression()) -> [Step] {
        let level = progression.level(forXP: totalXp)
        let current = progression.rank(forLevel: level)
        let ranks = progression.rules.ranks
        let index = ranks.firstIndex(of: current) ?? 0
        return ranks.enumerated().map { offset, rank in
            let state: RankState =
                switch offset {
                case ..<index: .reached
                case index: .current
                case index + 1:
                    .next(xpMissing: max(progression.xpToComplete(level: rank.minLevel - 1) - totalXp, 0))
                default: .locked
                }
            return Step(rank: rank, state: state)
        }
    }

    static func attributeRows(
        now: [Attribute: AttributeLevel], before: [Attribute: AttributeLevel], progression: Progression = Progression()
    ) -> [AttributeRow] {
        Attribute.allCases.map { attribute in
            let level = now[attribute] ?? AttributeLevel(xp: 0, level: 1)
            return AttributeRow(
                attribute: attribute, level: level.level, levelBefore: before[attribute]?.level ?? 1,
                fraction: progression.levelProgress(xp: level.xp).fraction)
        }
    }
}
