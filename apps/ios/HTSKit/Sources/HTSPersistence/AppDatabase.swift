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
        return migrator
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
