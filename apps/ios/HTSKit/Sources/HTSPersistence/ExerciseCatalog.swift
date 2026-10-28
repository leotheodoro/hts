import Foundation
import GRDB
import HTSDomain

/// Free-text exercise catalog, deduplicated by normalized name (docs/decisions/0016).
public struct ExerciseCatalog: Sendable {
    private let database: AppDatabase

    public init(_ database: AppDatabase) {
        self.database = database
    }

    /// Live exercises whose normalized name contains the query, best matches (prefix) first.
    public func search(_ query: String, athleteId: UUID, limit: Int = 20) async throws -> [Exercise] {
        let needle = ExerciseName.normalize(query)
        return try await database.writer.read { db in
            let pattern = "%" + needle.replacingOccurrences(of: "%", with: "") + "%"
            return try Exercise.filter(Columns.athleteId == athleteId.sql && Columns.deletedAt == nil)
                .filter(Column("normalized_name").like(pattern))
                .order(sql: "instr(normalized_name, ?) = 1 DESC, normalized_name", arguments: [needle])
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// The live exercise with the same normalized name, or a new one. Typing "barra  fixa" after "Barra Fixa"
    /// returns the existing exercise.
    public func findOrCreate(
        name: String, athleteId: UUID, defaultAttribute: Attribute? = nil, unit: ExerciseUnit = .reps,
        perSide: Bool = false, now: Date = .now
    ) async throws -> Exercise {
        let normalized = ExerciseName.normalize(name)
        return try await database.writer.write { db in
            if let existing = try Exercise.filter(
                Columns.athleteId == athleteId.sql && Column("normalized_name") == normalized
                    && Columns.deletedAt == nil
            ).fetchOne(db) {
                return existing
            }
            let exercise = Exercise(
                id: UUIDv7.make(at: now), athleteId: athleteId, name: name, defaultAttribute: defaultAttribute,
                unit: unit, perSide: perSide, createdAt: now)
            try exercise.insert(db)
            return exercise
        }
    }
}
