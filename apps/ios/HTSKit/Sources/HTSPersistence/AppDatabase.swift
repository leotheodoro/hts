import Foundation
import GRDB
import HTSDomain

/// The local SQLite database. The schema mirrors Postgres (apps/api/src/db/schema.ts):
/// same table and column names.
public final class AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// The app database in Application Support.
    public static func onDisk(fileManager: FileManager = .default) throws -> AppDatabase {
        let folder = try fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appending(path: "HTS", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "hts.sqlite")
        return try AppDatabase(DatabaseQueue(path: url.path(percentEncoded: false), configuration: configuration))
    }

    /// An empty, migrated database for tests and previews.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue(configuration: configuration))
    }

    private static var configuration: Configuration {
        var config = Configuration()
        config.foreignKeysEnabled = true
        return config
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
            migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("v1_create_athlete") { db in
            try db.create(table: "athlete") { t in
                t.primaryKey("id", .text)
                t.column("display_name", .text).notNull()
                t.column("default_rest_seconds", .integer).notNull().defaults(to: Athlete.defaultRestSeconds)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
                t.column("deleted_at", .text)
            }
        }
        migrator.registerMigration("v2_create_plan", migrate: createPlan)
        migrator.registerMigration("v3_create_record", migrate: createRecord)
        migrator.registerMigration("v4_create_battle") { db in
            // Mirrors apps/api/drizzle/0003_create_battle.sql.
            try db.create(table: "battle") { t in
                owned(t)
                t.column("saga_id", .text).notNull().references("saga")
                t.column("name", .text).notNull()
                t.column("date", .text).notNull()
                t.column("result", .text).check(sql: "result IN (\(oneOf(BattleResult.self)))")
                timestamps(t)
            }
            try db.execute(sql: "CREATE INDEX battle_athlete_date_idx ON battle(athlete_id, date)")
        }
        migrator.registerMigration("v5_create_local_sync_state") { db in
            // Device-only (docs/decisions/0026): `local_` tables are not mirrored in Postgres.
            try db.create(table: "local_sync_state") { t in
                t.primaryKey("key", .text)
                t.column("value", .text).notNull()
            }
        }
        migrator.registerMigration("v6_filler_never_current") { db in
            // Filler arcs stopped taking the current slot (docs/decisions/0028). Touch updated_at so the fix syncs.
            try db.execute(
                sql: """
                    UPDATE arc SET status = 'queued', updated_at = ?
                    WHERE kind = 'filler' AND status = 'current' AND deleted_at IS NULL
                    """, arguments: [ISO8601Millis.format(.now)])
        }
        migrator.registerMigration("v7_saga_to_season", migrate: sagaToSeason)
        // The old yearly saga could be left with no arcs once Manutenção became free (#83). Soft-delete empty
        // seasons so the deletion syncs; if the active one goes, the first remaining season takes its place.
        migrator.registerMigration("v8_drop_empty_seasons") { db in
            let stamp = ISO8601Millis.format(.now)
            try db.execute(
                sql: """
                    UPDATE season SET deleted_at = ?, updated_at = ?, active = 0
                    WHERE deleted_at IS NULL
                    AND NOT EXISTS (SELECT 1 FROM arc WHERE arc.season_id = season.id AND arc.deleted_at IS NULL);
                    UPDATE season SET active = 1, updated_at = ?
                    WHERE id = (
                        SELECT s.id FROM season s WHERE s.athlete_id = season.athlete_id AND s.deleted_at IS NULL
                        ORDER BY s.position LIMIT 1)
                    AND NOT EXISTS (
                        SELECT 1 FROM season a WHERE a.athlete_id = season.athlete_id AND a.active
                        AND a.deleted_at IS NULL);
                    UPDATE arc SET status = 'current', updated_at = ?
                    WHERE id IN (
                        SELECT (SELECT r.id FROM arc r WHERE r.season_id = s.id AND r.status = 'queued'
                                AND r.kind != 'filler' AND r.deleted_at IS NULL ORDER BY r.position LIMIT 1)
                        FROM season s WHERE s.active AND s.deleted_at IS NULL)
                    AND NOT EXISTS (
                        SELECT 1 FROM arc c WHERE c.athlete_id = arc.athlete_id AND c.status = 'current'
                        AND c.deleted_at IS NULL);
                    """, arguments: [stamp, stamp, stamp, stamp])
        }
        // Mirrors apps/api/drizzle/0006: the coach's video per exercise (#110).
        migrator.registerMigration("v9_exercise_video_url") { db in
            try db.alter(table: "exercise") { t in t.add(column: "video_url", .text) }
        }
        // Accounts arrive (docs/decisions/0031): the data from before them was test data. Wipe it once so the
        // first login pulls the account's own data into an empty database.
        migrator.registerMigration("v10_start_fresh") { db in
            for table in [
                "logged_round", "logged_set", "session", "battle", "prescribed_exercise", "exercise", "block",
                "workout_template", "arc", "season", "athlete", "local_sync_state",
            ] {
                try db.execute(sql: "DELETE FROM \(table)")
            }
        }
        // Mirrors apps/api/drizzle/0009: activities pushed by Garmin, read-only here (docs/decisions/0033).
        migrator.registerMigration("v11_imported_activity") { db in
            try db.create(table: "imported_activity") { t in
                owned(t)
                t.column("source", .text).notNull()
                t.column("external_id", .text).notNull()
                t.column("activity_type", .text).notNull()
                t.column("name", .text)
                t.column("started_at", .text).notNull()
                t.column("duration_seconds", .integer).notNull()
                t.column("distance_meters", .text)
                t.column("average_heart_rate", .integer)
                t.column("calories", .integer)
                timestamps(t)
            }
            try db.execute(
                sql: """
                    CREATE UNIQUE INDEX imported_activity_source_external_id_idx ON imported_activity(source, external_id);
                    CREATE INDEX imported_activity_athlete_started_at_idx ON imported_activity(athlete_id, started_at);
                    """)
        }
        return migrator
    }

    /// Mirrors apps/api/drizzle/0005_rename_saga_to_season.sql (docs/decisions/0029). SQLite cannot make a column
    /// nullable, so `arc` and `battle` are rebuilt; GRDB runs migrations with foreign keys checked at the end.
    private static func sagaToSeason(_ db: Database) throws {
        let stamp = ISO8601Millis.format(.now)
        try db.execute(
            sql: """
                ALTER TABLE saga RENAME TO season;
                ALTER TABLE season DROP COLUMN year;
                ALTER TABLE season ADD COLUMN position INTEGER NOT NULL DEFAULT 0;
                ALTER TABLE season ADD COLUMN active BOOLEAN NOT NULL DEFAULT 0;
                """)

        try db.create(table: "arc_new") { t in
            owned(t)
            t.column("season_id", .text).references("season")
            t.column("name", .text).notNull()
            t.column("kanji", .text)
            t.column("program", .text)
            t.column("kind", .text).notNull().defaults(to: ArcKind.normal.rawValue)
                .check(sql: "kind IN (\(oneOf(ArcKind.self)))")
            t.column("weeks", .integer)
            t.column("start_date", .text)
            t.column("status", .text).notNull().defaults(to: ArcStatus.queued.rawValue)
                .check(sql: "status IN (\(oneOf(ArcStatus.self)))")
            t.column("position", .integer).notNull()
            t.column("count_reset_at", .text)
            timestamps(t)
        }
        try db.execute(
            sql: """
                INSERT INTO arc_new (id, athlete_id, season_id, name, kanji, program, kind, weeks, start_date, status,
                    position, count_reset_at, created_at, updated_at, deleted_at)
                SELECT id, athlete_id, saga_id, name, kanji, program, kind, weeks, start_date, status,
                    position, count_reset_at, created_at, updated_at, deleted_at FROM arc;
                DROP TABLE arc;
                ALTER TABLE arc_new RENAME TO arc;
                CREATE INDEX arc_season_id_idx ON arc(season_id);
                CREATE UNIQUE INDEX arc_one_current_idx ON arc(athlete_id) WHERE status = 'current' AND deleted_at IS NULL;
                """)

        try db.create(table: "battle_new") { t in
            owned(t)
            t.column("season_id", .text).references("season")
            t.column("name", .text).notNull()
            t.column("date", .text).notNull()
            t.column("result", .text).check(sql: "result IN (\(oneOf(BattleResult.self)))")
            timestamps(t)
        }
        try db.execute(
            sql: """
                INSERT INTO battle_new (id, athlete_id, season_id, name, date, result, created_at, updated_at, deleted_at)
                SELECT id, athlete_id, saga_id, name, date, result, created_at, updated_at, deleted_at FROM battle;
                DROP TABLE battle;
                ALTER TABLE battle_new RENAME TO battle;
                CREATE INDEX battle_athlete_date_idx ON battle(athlete_id, date);
                """)

        // Same data fixes as Postgres: filler arcs are free; the season holding the current arc is active.
        try db.execute(
            sql: """
                UPDATE arc SET season_id = NULL, updated_at = ? WHERE kind = 'filler' AND season_id IS NOT NULL;
                UPDATE season SET active = 1, updated_at = ?
                WHERE id IN (SELECT season_id FROM arc WHERE status = 'current' AND deleted_at IS NULL AND season_id IS NOT NULL);
                CREATE UNIQUE INDEX season_one_active_idx ON season(athlete_id) WHERE active AND deleted_at IS NULL;
                """, arguments: [stamp, stamp])
    }

    /// Mirrors apps/api/drizzle/0001_create_plan.sql. Postgres enums become TEXT with CHECK, jsonb becomes JSON
    /// TEXT, date becomes "YYYY-MM-DD" TEXT.
    private static func owned(_ t: TableDefinition) {
        t.primaryKey("id", .text)
        t.column("athlete_id", .text).notNull().references("athlete")
    }

    private static func timestamps(_ t: TableDefinition) {
        t.column("created_at", .text).notNull()
        t.column("updated_at", .text).notNull()
        t.column("deleted_at", .text)
    }

    private static func oneOf<E: RawRepresentable & CaseIterable>(_: E.Type) -> String where E.RawValue == String {
        E.allCases.map { "'\($0.rawValue)'" }.joined(separator: ", ")
    }

    private static func createPlan(_ db: Database) throws {
        try db.create(table: "saga") { t in
            owned(t)
            t.column("year", .integer).notNull()
            t.column("name", .text).notNull()
            timestamps(t)
        }
        try db.create(table: "arc") { t in
            owned(t)
            t.column("saga_id", .text).notNull().references("saga")
            t.column("name", .text).notNull()
            t.column("kanji", .text)
            t.column("program", .text)
            t.column("kind", .text).notNull().defaults(to: ArcKind.normal.rawValue)
                .check(sql: "kind IN (\(oneOf(ArcKind.self)))")
            t.column("weeks", .integer)
            t.column("start_date", .text)
            t.column("status", .text).notNull().defaults(to: ArcStatus.queued.rawValue)
                .check(sql: "status IN (\(oneOf(ArcStatus.self)))")
            t.column("position", .integer).notNull()
            t.column("count_reset_at", .text)
            timestamps(t)
        }
        try db.execute(
            sql:
                "CREATE UNIQUE INDEX arc_one_current_idx ON arc(athlete_id) WHERE status = 'current' AND deleted_at IS NULL"
        )
        try db.create(table: "workout_template") { t in
            owned(t)
            t.column("arc_id", .text).notNull().references("arc")
            t.column("source_template_id", .text)
            t.column("letter", .text).notNull()
            t.column("name", .text).notNull()
            t.column("focus", .text)
            t.column("position", .integer).notNull()
            timestamps(t)
        }
        try db.create(table: "block") { t in
            owned(t)
            t.column("workout_template_id", .text).notNull().references("workout_template")
            t.column("kind", .text).notNull().check(sql: "kind IN (\(oneOf(BlockKind.self)))")
            t.column("attributes", .jsonText).notNull()
            t.column("duration_minutes", .integer)
            t.column("position", .integer).notNull()
            timestamps(t)
        }
        try db.create(table: "exercise") { t in
            owned(t)
            t.column("name", .text).notNull()
            t.column("normalized_name", .text).notNull()
            t.column("default_attribute", .text).check(sql: "default_attribute IN (\(oneOf(Attribute.self)))")
            t.column("unit", .text).notNull().defaults(to: ExerciseUnit.reps.rawValue)
                .check(sql: "unit IN (\(oneOf(ExerciseUnit.self)))")
            t.column("per_side", .boolean).notNull().defaults(to: false)
            timestamps(t)
        }
        try db.execute(
            sql: """
                CREATE UNIQUE INDEX exercise_athlete_normalized_name_idx
                ON exercise(athlete_id, normalized_name) WHERE deleted_at IS NULL
                """)
        try db.create(table: "prescribed_exercise") { t in
            owned(t)
            t.column("block_id", .text).notNull().references("block")
            t.column("exercise_id", .text).notNull().references("exercise")
            t.column("sets_min", .integer).notNull()
            t.column("sets_max", .integer).notNull()
            t.column("targets", .jsonText).notNull()
            t.column("rest_seconds", .integer)
            t.column("position", .integer).notNull()
            timestamps(t)
        }
    }

    /// Mirrors apps/api/drizzle/0002_create_record.sql. Loads are decimal TEXT ("62.5"), never REAL.
    private static func createRecord(_ db: Database) throws {
        try db.create(table: "session") { t in
            owned(t)
            t.column("arc_id", .text).notNull().references("arc")
            t.column("workout_template_id", .text).notNull().references("workout_template")
            t.column("status", .text).notNull().defaults(to: SessionStatus.inProgress.rawValue)
                .check(sql: "status IN (\(oneOf(SessionStatus.self)))")
            t.column("started_at", .text).notNull()
            t.column("finished_at", .text)
            t.column("local_date", .text).notNull()
            t.column("plan_snapshot", .jsonText).notNull()
            timestamps(t)
        }
        try db.execute(
            sql: """
                CREATE INDEX session_athlete_started_at_idx ON session(athlete_id, started_at);
                CREATE INDEX session_workout_template_id_idx ON session(workout_template_id);
                CREATE UNIQUE INDEX session_one_in_progress_idx
                ON session(athlete_id) WHERE status = 'in_progress' AND deleted_at IS NULL;
                """)
        try db.create(table: "logged_set") { t in
            owned(t)
            t.column("session_id", .text).notNull().references("session")
            t.column("prescribed_exercise_id", .text).notNull().references("prescribed_exercise")
            t.column("exercise_id", .text).notNull().references("exercise")
            t.column("set_number", .integer).notNull()
            t.column("weight_kg", .text)
            t.column("reps", .integer)
            t.column("seconds", .integer)
            t.column("meters", .text)
            t.column("completed", .boolean).notNull().defaults(to: false)
            t.column("completed_at", .text)
            timestamps(t)
        }
        try db.execute(
            sql: """
                CREATE INDEX logged_set_session_id_idx ON logged_set(session_id);
                CREATE INDEX logged_set_exercise_id_idx ON logged_set(exercise_id);
                """)
        try db.create(table: "logged_round") { t in
            owned(t)
            t.column("session_id", .text).notNull().references("session")
            t.column("block_id", .text).notNull().references("block")
            t.column("rounds_completed", .integer).notNull().defaults(to: 0)
            t.column("weights", .jsonText).notNull()
            timestamps(t)
        }
        try db.execute(sql: "CREATE INDEX logged_round_session_id_idx ON logged_round(session_id)")
    }
}
