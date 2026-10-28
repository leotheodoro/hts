import Foundation
import GRDB
import HTSDomain

/// A plan to load on first launch, from a JSON file that stays out of git (apps/ios/LocalSeed/StarterPlan.json):
/// the coach's programs are licensed and the repository is public. Targets use the coach's notation
/// (TargetNotation).
public struct StarterPlan: Decodable, Sendable {
    public struct ArcSeed: Decodable, Sendable {
        public var name: String
        public var kanji: String?
        public var kind: ArcKind?
        public var weeks: Int?
        public var templates: [TemplateSeed]
    }

    public struct TemplateSeed: Decodable, Sendable {
        public var name: String
        public var focus: String?
        public var blocks: [BlockSeed]
    }

    public struct BlockSeed: Decodable, Sendable {
        public var kind: BlockKind
        public var attributes: [Attribute]
        public var durationMinutes: Int?
        public var exercises: [ExerciseSeed]
    }

    public struct ExerciseSeed: Decodable, Sendable {
        public var name: String
        public var unit: ExerciseUnit?
        /// "3" or "3 a 4".
        public var sets: String
        /// "8", "6-6-3-3", "12/12", "20 s", "máx".
        public var target: String
        public var restSeconds: Int?
    }

    public var arcs: [ArcSeed]

    public static func load(from url: URL) throws -> StarterPlan {
        try JSONDecoder().decode(StarterPlan.self, from: Data(contentsOf: url))
    }
}

public enum StarterPlanError: Error, Equatable {
    case invalidTemplate(String)
}

extension StarterPlan {
    private static let importedKey = "starter_plan_imported"

    /// Imports the plan once, and only when the athlete has no arcs yet (a reinstall that already synced its arcs
    /// keeps them). Returns whether it imported.
    @discardableResult
    public func importIfNeeded(
        into database: AppDatabase, athleteId: UUID, today: LocalDate, now: Date = .now
    ) async throws -> Bool {
        let alreadyDone = try await database.writer.read { db in
            let imported =
                try String.fetchOne(
                    db, sql: "SELECT value FROM local_sync_state WHERE key = ?", arguments: [Self.importedKey]) != nil
            let arcs =
                try Int.fetchOne(
                    db, sql: "SELECT COUNT(*) FROM arc WHERE athlete_id = ? AND deleted_at IS NULL",
                    arguments: [athleteId.sql]) ?? 0
            return imported || arcs > 0
        }
        guard !alreadyDone else { return false }

        let arcService = ArcService(database)
        let templates = TemplateService(database)
        let saga = try await arcService.saga(athleteId: athleteId, year: today.year, now: now)
        for seed in arcs {
            let draft = ArcDraft(
                name: seed.name, kanji: seed.kanji ?? "", kind: seed.kind ?? .normal, weeks: seed.weeks ?? 1,
                startDate: today, templates: seed.templates.map { .init(origin: .new, name: $0.name, focus: $0.focus) })
            let arc = try await arcService.save(draft, athleteId: athleteId, sagaId: saga.id, now: now)
            guard let plan = try await PlanRepository(database).plan(arcId: arc.id) else { continue }
            for (templatePlan, templateSeed) in zip(plan.templates, seed.templates) {
                guard var templateDraft = try await templates.draft(templateId: templatePlan.template.id) else {
                    continue
                }
                templateDraft.focus = templateSeed.focus ?? ""
                templateDraft.blocks = templateSeed.blocks.map { block in
                    TemplateDraft.BlockDraft(
                        kind: block.kind, attributes: block.attributes, durationMinutes: block.durationMinutes ?? 8,
                        exercises: block.exercises.map {
                            .init(
                                name: $0.name, unit: $0.unit ?? .reps, setsText: $0.sets, targetText: $0.target,
                                restSeconds: $0.restSeconds)
                        })
                }
                guard templateDraft.isValid else { throw StarterPlanError.invalidTemplate(templateSeed.name) }
                try await templates.save(templateDraft, now: now)
            }
        }
        try await database.writer.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO local_sync_state (key, value) VALUES (?, ?)",
                arguments: [Self.importedKey, ISO8601Millis.format(now)])
        }
        return true
    }
}
