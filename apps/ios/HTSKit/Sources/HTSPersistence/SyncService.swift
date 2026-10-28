import Foundation
import GRDB
import HTSDomain

/// How the sync reaches the API. HTSAPI implements it; tests use a fake server.
public protocol SyncTransport: Sendable {
    func push(_ changes: SyncChanges) async throws -> Int
    func pull(since: String?) async throws -> (cursor: String?, changes: SyncChanges)
}

/// Offline-first sync with the API (docs/decisions/0026): every write lands in SQLite first; a sync pushes rows
/// changed since the last push and pulls what the server wrote since the last cursor. Last write wins by
/// `updated_at`, on both sides.
public struct SyncService: Sendable {
    public struct Result: Hashable, Sendable {
        public let pushed: Int
        public let pulled: Int
    }

    /// Parents before children, the same order as the API.
    static let tables = [
        "athlete", "saga", "arc", "workout_template", "block", "exercise", "prescribed_exercise", "session",
        "logged_set", "logged_round", "battle",
    ]
    /// SQLite stores these as 0/1; the API expects booleans.
    static let booleanColumns: Set<String> = ["completed", "per_side"]
    /// SQLite stores these as JSON text; the API expects JSON.
    static let jsonColumns: Set<String> = ["attributes", "targets", "plan_snapshot", "weights"]

    private let database: AppDatabase
    private let transport: any SyncTransport

    public init(_ database: AppDatabase, transport: any SyncTransport) {
        self.database = database
        self.transport = transport
    }

    @discardableResult
    public func sync() async throws -> Result {
        let (changes, newestUpdate) = try await localChanges()
        var pushed = 0
        if !changes.isEmpty {
            pushed = try await transport.push(changes)
        }
        if let newestUpdate { try await setState("last_push_at", newestUpdate) }

        let cursor = try await state("pull_cursor")
        let remote = try await transport.pull(since: cursor)
        let pulled = try await apply(remote.changes)
        if let next = remote.cursor { try await setState("pull_cursor", next) }
        try await setState("last_sync_at", ISO8601Millis.format(.now))
        return Result(pushed: pushed, pulled: pulled)
    }

    /// When the last sync finished, if ever.
    public func lastSyncAt() async throws -> Date? {
        try await state("last_sync_at").flatMap(ISO8601Millis.parse)
    }

    /// Rows with `updated_at` at or after the last push (all rows on the first sync), and the newest stamp seen.
    func localChanges() async throws -> (SyncChanges, String?) {
        let since = try await state("last_push_at")
        return try await database.writer.read { db in
            var changes: SyncChanges = [:]
            var newest = since
            for table in Self.tables {
                let rows = try Row.fetchAll(
                    db, sql: "SELECT * FROM \(table) WHERE ? IS NULL OR updated_at >= ?", arguments: [since, since])
                guard !rows.isEmpty else { continue }
                changes[table] = rows.map(Self.wire)
                for row in rows {
                    let stamp: String = row["updated_at"]
                    if newest == nil || stamp > newest! { newest = stamp }
                }
            }
            return (changes, newest)
        }
    }

    /// Upserts pulled rows; a row only replaces the local one when its `updated_at` is not older.
    func apply(_ changes: SyncChanges) async throws -> Int {
        try await database.writer.write { db in
            var applied = 0
            for table in Self.tables {
                guard let rows = changes[table], !rows.isEmpty else { continue }
                let columns = try db.columns(in: table).map(\.name)
                for row in rows {
                    let present = columns.filter { row[$0] != nil }
                    guard present.contains("id") else { continue }
                    let names = present.map { "\"\($0)\"" }.joined(separator: ", ")
                    let marks = Array(repeating: "?", count: present.count).joined(separator: ", ")
                    let updates = present.filter { $0 != "id" }.map { "\"\($0)\" = excluded.\"\($0)\"" }
                        .joined(separator: ", ")
                    try db.execute(
                        sql: """
                            INSERT INTO \(table) (\(names)) VALUES (\(marks))
                            ON CONFLICT(id) DO UPDATE SET \(updates) WHERE \(table).updated_at <= excluded.updated_at
                            """,
                        arguments: StatementArguments(present.map { Self.databaseValue(row[$0]!, column: $0) }))
                    applied += 1
                }
            }
            return applied
        }
    }

    static func wire(_ row: Row) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for column in row.columnNames {
            let value: DatabaseValue = row[column]
            switch value.storage {
            case .null: result[column] = .null
            case .int64(let int):
                result[column] = booleanColumns.contains(column) ? .bool(int != 0) : .number(Double(int))
            case .double(let double): result[column] = .number(double)
            case .string(let text):
                if jsonColumns.contains(column), let data = text.data(using: .utf8),
                    let json = try? JSONDecoder().decode(JSONValue.self, from: data)
                {
                    result[column] = json
                } else {
                    result[column] = .string(text)
                }
            case .blob: result[column] = .null
            }
        }
        return result
    }

    static func databaseValue(_ value: JSONValue, column: String) -> DatabaseValue {
        switch value {
        case .null: return .null
        case .bool(let bool): return (bool ? 1 : 0).databaseValue
        case .number(let number):
            return number.rounded() == number ? Int64(number).databaseValue : number.databaseValue
        case .string(let text):
            // Postgres numeric comes back as "62.50"; keep the shortest exact decimal like the app writes it.
            if column == "weight_kg" || column == "meters",
                let decimal = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
            {
                return decimal.databaseValue
            }
            return text.databaseValue
        case .array, .object:
            let data = (try? JSONEncoder().encode(value)) ?? Data("null".utf8)
            return String(decoding: data, as: UTF8.self).databaseValue
        }
    }

    private func state(_ key: String) async throws -> String? {
        try await database.writer.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM local_sync_state WHERE key = ?", arguments: [key])
        }
    }

    private func setState(_ key: String, _ value: String) async throws {
        try await database.writer.write { db in
            try db.execute(
                sql:
                    "INSERT INTO local_sync_state (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                arguments: [key, value])
        }
    }
}
