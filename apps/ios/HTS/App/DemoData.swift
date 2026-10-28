#if DEBUG
    import Foundation
    import HTSDomain
    import HTSPersistence

    /// Sample arcs for screenshots and manual checks: launch with `-HTSSeedDemo YES`. Only when there are no arcs.
    enum DemoData {
        static var isRequested: Bool { UserDefaults.standard.bool(forKey: "HTSSeedDemo") }

        static func seed(_ database: AppDatabase, athleteId: UUID) async throws {
            let service = ArcService(database)
            let today = LocalDate.today
            let saga = try await service.saga(athleteId: athleteId, year: today.year)
            guard try await service.summaries(athleteId: athleteId, sagaId: saga.id).isEmpty else { return }
            let arcs: [ArcDraft] = [
                ArcDraft(
                    name: "Recrutamento", kanji: "募", weeks: 2, startDate: today.adding(days: -10),
                    templates: ["Linha de Frente", "Trincheira", "Bombardeio"].map { .init(origin: .new, name: $0) }),
                ArcDraft(
                    name: "Forja", kanji: "鍛", weeks: 2, startDate: today.adding(days: 4),
                    templates: ["Blindado", "Paraquedista", "Marcha Forçada"].map { .init(origin: .new, name: $0) }),
                ArcDraft(
                    name: "Manutenção", kind: .filler, startDate: today,
                    templates: ["Patrulha", "Sentinela"].map { .init(origin: .new, name: $0) }),
            ]
            for draft in arcs {
                try await service.save(draft, athleteId: athleteId, sagaId: saga.id)
            }
        }
    }
#endif
