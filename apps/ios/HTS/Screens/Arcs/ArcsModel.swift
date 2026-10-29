import Foundation
import HTSDomain
import HTSPersistence
import Observation

/// State of the Arcos tab: seasons with their arcs in order, and the free arcs (docs/decisions/0029).
@MainActor
@Observable
final class ArcsModel {
    struct SeasonArcs: Identifiable {
        let season: Season
        let summaries: [ArcService.Summary]
        var id: UUID { season.id }
    }

    private(set) var seasons: [SeasonArcs] = []
    /// Arcs outside any season (Manutenção), always available.
    private(set) var freeArcs: [ArcService.Summary] = []
    private(set) var error: String?
    /// The competition ahead, to spotlight the special arc in its week.
    private(set) var battle: Battle?

    private let database: AppDatabase
    private let athleteId: UUID

    init(database: AppDatabase, athleteId: UUID) {
        self.database = database
        self.athleteId = athleteId
    }

    var service: ArcService { ArcService(database) }
    var activeSeason: Season? { seasons.first { $0.season.active }?.season }

    func load(now: Date = .now) async {
        do {
            var loaded: [SeasonArcs] = []
            for season in try await SeasonService(database).seasons(athleteId: athleteId) {
                loaded.append(
                    SeasonArcs(
                        season: season,
                        summaries: try await service.summaries(athleteId: athleteId, seasonId: season.id)))
            }
            seasons = loaded
            freeArcs = try await service.summaries(athleteId: athleteId, seasonId: nil)
            battle = try await BattleRepository(database).current(
                athleteId: athleteId, today: LocalDate(now, in: .current))
            error = nil
        } catch {
            self.error = String(describing: error)
        }
    }

    /// Makes `season` the active one; the previous season pauses on its current arc.
    func activate(_ season: Season) async {
        do {
            try await SeasonService(database).activate(seasonId: season.id, athleteId: athleteId)
            await load()
        } catch {
            self.error = String(describing: error)
        }
    }

    // MARK: Arc form (hidden for now, #64)

    func newDraft() -> ArcDraft {
        ArcDraft(startDate: .today)
    }

    func draft(for arcId: UUID) async -> ArcDraft? {
        guard let plan = try? await PlanRepository(database).plan(arcId: arcId) else { return nil }
        return ArcDraft(plan, today: .today)
    }

    func reusableTemplates(excluding arcId: UUID?) async -> [(arc: Arc, template: WorkoutTemplate)] {
        (try? await service.reusableTemplates(athleteId: athleteId, excludingArc: arcId)) ?? []
    }

    /// New arcs go to the active season, Manutenção arcs to the free ones. Returns false on failure.
    func save(_ draft: ArcDraft) async -> Bool {
        do {
            try await service.save(
                draft, athleteId: athleteId, seasonId: draft.kind == .filler ? nil : activeSeason?.id)
            await load()
            return true
        } catch {
            self.error = String(describing: error)
            return false
        }
    }

    func restartCount(arcId: UUID) async {
        do {
            try await service.restartCount(arcId: arcId)
            await load()
        } catch {
            self.error = String(describing: error)
        }
    }
}
