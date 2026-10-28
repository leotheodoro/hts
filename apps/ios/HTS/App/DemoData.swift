#if DEBUG
    import Foundation
    import HTSDomain
    import HTSPersistence

    /// Sample arcs for screenshots and manual checks: launch with `-HTSSeedDemo YES`. Only when there are no arcs.
    enum DemoData {
        static var isRequested: Bool { UserDefaults.standard.bool(forKey: "HTSSeedDemo") }
        /// `-HTSStartDemoWorkout YES` starts the suggested workout on launch (screenshots).
        static var startsWorkout: Bool { UserDefaults.standard.bool(forKey: "HTSStartDemoWorkout") }

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
            guard let first = try await service.summaries(athleteId: athleteId, sagaId: saga.id).first,
                let plan = try await PlanRepository(database).plan(arcId: first.arc.id),
                var template = try await TemplateService(database).draft(templateId: plan.templates[0].template.id)
            else { return }
            template.focus = "Força e explosão"
            template.blocks = [
                .init(
                    kind: .activation, attributes: [.mobility],
                    exercises: [
                        .init(name: "Prancha", unit: .seconds, setsText: "3", targetText: "30-45 s")
                    ]),
                .init(
                    kind: .strength, attributes: [.strength],
                    exercises: [
                        .init(name: "Zercher Squat", setsText: "4", targetText: "6-6-3-3", restSeconds: 150),
                        .init(name: "Afundo Búlgaro", setsText: "3 a 4", targetText: "10/10"),
                    ]),
                .init(
                    kind: .fightRound, attributes: [.conditioning, .power], durationMinutes: 8,
                    exercises: [
                        .init(name: "Swing Russo", setsText: "1", targetText: "máx", restSeconds: 30)
                    ]),
            ]
            try await TemplateService(database).save(template)

            // A finished session of template A two days ago, so "Anterior" has values.
            guard let filled = try await PlanRepository(database).plan(arcId: first.arc.id)?.templates.first else {
                return
            }
            let sessions = SessionRepository(database)
            let started = Date.now.addingTimeInterval(-2 * 86_400)
            let past = try await sessions.start(filled, now: started)
            for var set in try await sessions.sets(sessionId: past.id) {
                let isZercher = set.exerciseId == filled.blocks[1].exercises[0].exercise.id
                set.weightKg = isZercher ? [60, 62.5, 70, 70][min(set.setNumber - 1, 3)] : 20
                set.reps = isZercher ? [6, 6, 3, 3][min(set.setNumber - 1, 3)] : 10
                set.seconds = set.exerciseId == filled.blocks[0].exercises[0].exercise.id ? 40 : nil
                set.completed = true
                try await sessions.save(set)
            }
            _ = try await sessions.finish(sessionId: past.id, now: started.addingTimeInterval(3_900))
        }
    }
#endif
