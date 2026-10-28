/// A completed or open set as the attributes see it. Mirrors `AttributeSet` in packages/progression.
public struct AttributeSet: Hashable, Sendable, Decodable {
    public let attributes: [Attribute]
    public let completed: Bool

    public init(attributes: [Attribute], completed: Bool) {
        self.attributes = attributes
        self.completed = completed
    }
}

public struct AttributeLevel: Hashable, Sendable, Decodable {
    public let xp: Int
    public let level: Int

    public init(xp: Int, level: Int) {
        self.xp = xp
        self.level = level
    }
}

extension Progression {
    /// Each attribute has its own level on the athlete's curve (docs/decisions/0023). Must match `attributeLevels`
    /// in packages/progression; both run packages/fixtures/attribute-levels.json.
    public func attributeLevels(_ sets: [AttributeSet]) -> [Attribute: AttributeLevel] {
        var xp = Dictionary(uniqueKeysWithValues: Attribute.allCases.map { ($0, 0) })
        for set in sets where set.completed {
            for attribute in Set(set.attributes) { xp[attribute, default: 0] += rules.xp.setCompleted }
        }
        return xp.mapValues { AttributeLevel(xp: $0, level: level(forXP: $0)) }
    }
}
