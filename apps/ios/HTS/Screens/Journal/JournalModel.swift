import Foundation
import HTSDomain
import HTSPersistence
import Observation

/// Journal: totals, records per exercise and the sessions, newest first.
@MainActor
@Observable
final class JournalModel {
    struct Entry: Identifiable {
        let session: Session
        let progress: SessionProgress
        /// TR number (position among all sessions).
        let number: Int
        var id: UUID { session.id }
    }

    private(set) var entries: [Entry] = []
    private(set) var records: [ProgressService.Record] = []
    private(set) var totalSets = 0
    private(set) var totalVolume: Decimal = 0

    let database: AppDatabase
    private let athleteId: UUID

    init(database: AppDatabase, athleteId: UUID) {
        self.database = database
        self.athleteId = athleteId
    }

    func load() async {
        guard let (sessions, history) = try? await ProgressService(database).history(athleteId: athleteId) else {
            return
        }
        entries = zip(sessions, history.sessions).enumerated()
            .map { Entry(session: $1.0, progress: $1.1, number: $0 + 1) }
            .reversed()
        totalSets = history.sessions.reduce(0) { $0 + $1.completedSets }
        totalVolume = history.sessions.reduce(0) { $0 + $1.volumeKg }
        records = (try? await ProgressService(database).records(athleteId: athleteId)) ?? []
    }

    /// Soft delete; XP, records, streak and numbering recompute from what is left.
    func delete(_ session: Session) async {
        try? await SessionRepository(database).delete(sessionId: session.id)
        await load()
    }
}

extension LoggedSet {
    /// "062.5 KG × 06": data style of the design system, zero padded.
    static func plate(kg: Decimal, reps: Int?) -> String {
        let value = NSDecimalNumber(decimal: kg).doubleValue
        let kgText = String(format: "%05.1f", value)
        return reps.map { "\(kgText) KG × \(String(format: "%02d", $0))" } ?? "\(kgText) KG"
    }
}
