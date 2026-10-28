import Foundation

public enum BattleResult: String, Codable, Sendable, CaseIterable {
    case gold, silver, bronze, participation
}

/// A Batalha: the competition that closes the season (docs/product/handoff-produto.md, Arcos especiais).
public struct Battle: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var athleteId: UUID
    public var sagaId: UUID
    public var name: String
    public var date: LocalDate
    public var result: BattleResult?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID, athleteId: UUID, sagaId: UUID, name: String, date: LocalDate, result: BattleResult? = nil,
        createdAt: Date, updatedAt: Date? = nil, deletedAt: Date? = nil
    ) {
        self.id = id
        self.athleteId = athleteId
        self.sagaId = sagaId
        self.name = name
        self.date = date
        self.result = result
        self.createdAt = createdAt.roundedToMilliseconds
        self.updatedAt = (updatedAt ?? createdAt).roundedToMilliseconds
        self.deletedAt = deletedAt?.roundedToMilliseconds
    }

    /// Days from `today` to the competition; 0 on the day, negative after.
    public func daysUntil(_ today: LocalDate) -> Int { today.days(to: date) }

    /// Less than 7 days away: the special arc (A Véspera) gets the spotlight.
    public func isEve(_ today: LocalDate) -> Bool { (0..<7).contains(daysUntil(today)) }
}
