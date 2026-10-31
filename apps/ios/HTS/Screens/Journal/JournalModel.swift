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

    /// One line of the journal: a workout or an activity imported from Garmin (spec 2026-10-31).
    enum Item: Identifiable {
        case session(Entry)
        case activity(ProgressService.ActivityEntry)

        var id: UUID {
            switch self {
            case .session(let entry): entry.session.id
            case .activity(let entry): entry.activity.id
            }
        }

        var startedAt: Date {
            switch self {
            case .session(let entry): entry.session.startedAt
            case .activity(let entry): entry.activity.startedAt
            }
        }
    }

    private(set) var entries: [Entry] = []
    /// Workouts and unlinked activities, newest first.
    private(set) var items: [Item] = []
    /// Activities recorded inside a workout, by the workout's id: they show in its detail, not as items.
    private(set) var linkedActivities: [UUID: ImportedActivity] = [:]
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
        let activities = (try? await ProgressService(database).activities(athleteId: athleteId)) ?? []
        linkedActivities = Dictionary(
            activities.compactMap { entry in entry.linkedSessionId.map { ($0, entry.activity) } },
            uniquingKeysWith: { first, _ in first })
        items = (entries.map(Item.session) + activities.filter { $0.linkedSessionId == nil }.map(Item.activity))
            .sorted { $0.startedAt > $1.startedAt }
        // The totals stay about the HTS workouts.
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
