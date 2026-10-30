import Foundation
import GRDB
import HTSDomain

/// The athlete's plan, from a JSON file that stays out of git (apps/ios/LocalSeed/StarterPlan.json): the coach's
/// programs are licensed and the repository is public. Seasons hold arcs in order; free arcs (Manutenção) belong to
/// no season. Targets use the coach's notation (TargetNotation). The import is additive by name, so new arcs can be
/// appended to the file later (docs/decisions/0029).
public struct StarterPlan: Decodable, Sendable {
    public struct SeasonSeed: Decodable, Sendable {
        public var name: String
        public var arcs: [ArcSeed]
    }

    public struct ArcSeed: Decodable, Sendable {
        public var name: String
        /// Required: every arc has a kanji (#79).
        public var kanji: String
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
        /// The coach's YouTube link (#110).
        public var video: String?
    }

    public var seasons: [SeasonSeed]
    /// Free arcs, always available. They are imported as Manutenção.
    public var arcs: [ArcSeed]

    private enum CodingKeys: String, CodingKey { case seasons, arcs }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seasons = try c.decodeIfPresent([SeasonSeed].self, forKey: .seasons) ?? []
        arcs = try c.decodeIfPresent([ArcSeed].self, forKey: .arcs) ?? []
    }

    public static func load(from url: URL) throws -> StarterPlan {
        try JSONDecoder().decode(StarterPlan.self, from: Data(contentsOf: url))
    }
}

public enum StarterPlanError: Error, Equatable {
    case invalidTemplate(String)
}

extension StarterPlan {
    /// Adds every season and arc of the plan that the athlete does not have yet, matched by name (arcs by name
    /// inside their season, or among free arcs). Existing arcs are left untouched so history never changes.
    /// Returns how many arcs were added.
    @discardableResult
    public func importMissing(
        into database: AppDatabase, athleteId: UUID, today: LocalDate, now: Date = .now
    ) async throws -> Int {
        var added = 0
        for seasonSeed in seasons {
            let season = try await SeasonService(database).season(
                named: seasonSeed.name, athleteId: athleteId, now: now)
            for arcSeed in seasonSeed.arcs {
                if try await Self.add(
                    arcSeed, seasonId: season.id, into: database, athleteId: athleteId, today: today, now: now)
                {
                    added += 1
                }
            }
        }
        for var arcSeed in arcs {
            arcSeed.kind = .filler
            if try await Self.add(arcSeed, seasonId: nil, into: database, athleteId: athleteId, today: today, now: now)
            {
                added += 1
            }
        }
        return added
    }

    /// Gives each catalog exercise the plan's video when it has none yet, matched by normalized name, so arcs
    /// imported before the links existed get them too. A link the athlete already has is kept. Returns how many
    /// exercises changed.
    @discardableResult
    public func fillVideos(into database: AppDatabase, athleteId: UUID, now: Date = .now) async throws -> Int {
        var videos: [String: String] = [:]
        for arc in seasons.flatMap(\.arcs) + arcs {
            for exercise in arc.templates.flatMap(\.blocks).flatMap(\.exercises) {
                guard let video = exercise.video else { continue }
                videos[ExerciseName.normalize(exercise.name), default: video] = video
            }
        }
        let stamp = ISO8601Millis.format(now)
        return try await database.writer.write { [videos] db in
            var changed = 0
            for (name, video) in videos {
                try db.execute(
                    sql: """
                        UPDATE exercise SET video_url = ?, updated_at = ?
                        WHERE athlete_id = ? AND normalized_name = ? AND video_url IS NULL AND deleted_at IS NULL
                        """, arguments: [video, stamp, athleteId.sql, name])
                changed += db.changesCount
            }
            return changed
        }
    }

    private static func add(
        _ seed: ArcSeed, seasonId: UUID?, into database: AppDatabase, athleteId: UUID, today: LocalDate, now: Date
    ) async throws -> Bool {
        let exists = try await database.writer.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM arc WHERE athlete_id = ? AND name = ? AND season_id IS ? AND deleted_at IS NULL
                    """, arguments: [athleteId.sql, seed.name, seasonId?.sql]) ?? 0
        }
        guard exists == 0 else { return false }

        let draft = ArcDraft(
            name: seed.name, kanji: seed.kanji, kind: seed.kind ?? .normal, weeks: seed.weeks ?? 1,
            startDate: today, templates: seed.templates.map { .init(origin: .new, name: $0.name, focus: $0.focus) })
        let arc = try await ArcService(database).save(draft, athleteId: athleteId, seasonId: seasonId, now: now)
        guard let plan = try await PlanRepository(database).plan(arcId: arc.id) else { return true }
        let templates = TemplateService(database)
        for (templatePlan, templateSeed) in zip(plan.templates, seed.templates) {
            guard var templateDraft = try await templates.draft(templateId: templatePlan.template.id) else { continue }
            templateDraft.focus = templateSeed.focus ?? ""
            templateDraft.blocks = templateSeed.blocks.map { block in
                TemplateDraft.BlockDraft(
                    kind: block.kind, attributes: block.attributes, durationMinutes: block.durationMinutes ?? 8,
                    exercises: block.exercises.map {
                        TemplateDraft.ExerciseDraft(
                            name: $0.name, unit: $0.unit ?? .reps, setsText: $0.sets, targetText: $0.target,
                            restSeconds: $0.restSeconds)
                    })
            }
            guard templateDraft.isValid else { throw StarterPlanError.invalidTemplate(templateSeed.name) }
            try await templates.save(templateDraft, now: now)
        }
        return true
    }
}
