import Foundation
import GRDB

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
        return migrator
    }
}
