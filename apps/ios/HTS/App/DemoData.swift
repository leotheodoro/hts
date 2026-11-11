#if DEBUG
    import Foundation
    import HTSDomain
    import HTSPersistence

    /// Sample arcs for screenshots and manual checks: launch with `-HTSSeedDemo YES`. Only when there are no arcs.
    enum DemoData {
        static var isRequested: Bool { UserDefaults.standard.bool(forKey: "HTSSeedDemo") }
        /// `-HTSFakeSession YES` (implied by the demo flags) opens with a local athlete and a session that never
        /// reaches the API, so screenshots skip the login.
        static var usesLocalSession: Bool {
            UserDefaults.standard.bool(forKey: "HTSFakeSession") || isRequested || startsWorkout || activitiesRequested
        }
        /// `-HTSStartDemoWorkout YES` starts the suggested workout on launch (screenshots).
        static var startsWorkout: Bool { UserDefaults.standard.bool(forKey: "HTSStartDemoWorkout") }
        /// `-HTSDemoActivities YES` adds Garmin activities to the local athlete (#167): Diário and Integrações
        /// without the Garmin access.
        static var activitiesRequested: Bool { UserDefaults.standard.bool(forKey: "HTSDemoActivities") }

        static func seed(_ database: AppDatabase, athleteId: UUID) async throws {
            let service = ArcService(database)
            let today = LocalDate.today
            let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athleteId)
            guard try await service.summaries(athleteId: athleteId, seasonId: season.id).isEmpty else { return }
            let arcs: [ArcDraft] = [
                ArcDraft(
                    name: "Recrutamento", kanji: "募", weeks: 2, startDate: today.adding(days: -10),
                    templates: ["Linha de Frente", "Trincheira", "Bombardeio"].map { .init(origin: .new, name: $0) }),
                ArcDraft(
                    name: "Forja", kanji: "鍛", weeks: 2, startDate: today.adding(days: 4),
                    templates: ["Blindado", "Paraquedista", "Marcha Forçada"].map { .init(origin: .new, name: $0) }),
                ArcDraft(
                    name: "Manutenção", kanji: "守", kind: .filler, startDate: today,
                    templates: ["Patrulha", "Sentinela"].map { .init(origin: .new, name: $0) }),
                ArcDraft(
                    name: "A Véspera", kanji: "前", kind: .special, weeks: 1, startDate: today.adding(days: 1),
                    templates: [.init(origin: .new, name: "Fio da Navalha")]),
            ]
            for draft in arcs {
                try await service.save(draft, athleteId: athleteId, seasonId: draft.kind == .filler ? nil : season.id)
            }
            let performance = try await SeasonService(database).season(named: "Performance", athleteId: athleteId)
            try await service.save(
                ArcDraft(
                    name: "Adaptação", kanji: "適", weeks: 2, startDate: today,
                    templates: [.init(origin: .new, name: "Base")]),
                athleteId: athleteId, seasonId: performance.id)
            try await BattleRepository(database).save(
                Battle(
                    id: UUIDv7.make(), athleteId: athleteId, seasonId: season.id, name: "Copa Hard To Submit",
                    date: today.adding(days: 5), createdAt: .now))
            guard let first = try await service.summaries(athleteId: athleteId, seasonId: season.id).first,
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
            try await seedTest(database, athleteId: athleteId)
        }

        /// A treino teste (#216) in the locked arc Forja, done twice, so EVOLUÇÃO has two columns.
        private static func seedTest(_ database: AppDatabase, athleteId: UUID) async throws {
            let plans = PlanRepository(database)
            let season = try await SeasonService(database).season(named: "Jiu-Jitsu", athleteId: athleteId)
            guard
                let forja = try await plans.arcs(athleteId: athleteId, seasonId: season.id)
                    .first(where: { $0.name == "Forja" })
            else { return }
            let test = WorkoutTemplate(
                id: UUIDv7.make(), athleteId: athleteId, arcId: forja.id, letter: "D", name: "Teste de Potência",
                position: 3, isTest: true, createdAt: .now)
            try await plans.save(test)
            guard var draft = try await TemplateService(database).draft(templateId: test.id) else { return }
            draft.blocks = [
                .init(
                    kind: .conditioning, attributes: [.power],
                    exercises: [
                        .init(name: "Salto em Distância", unit: .meters, setsText: "3", targetText: "máx"),
                        .init(name: "Bike Max Cal 30 s", unit: .calories, setsText: "1", targetText: "máx"),
                    ])
            ]
            try await TemplateService(database).save(draft)
            guard let plan = try await plans.template(id: test.id)?.plan else { return }
            let sessions = SessionRepository(database)
            for (daysAgo, jump, calories) in [(30, Decimal(2.3), 18), (3, Decimal(2.45), 17)] {
                let started = Date.now.addingTimeInterval(-Double(daysAgo) * 86_400)
                let run = try await sessions.start(plan, now: started)
                for var set in try await sessions.sets(sessionId: run.id) {
                    if set.exerciseId == plan.blocks[0].exercises[0].exercise.id {
                        set.meters = jump - Decimal(set.setNumber - 1) / 10
                    } else {
                        set.reps = calories
                    }
                    set.completed = true
                    try await sessions.save(set)
                }
                _ = try await sessions.finish(sessionId: run.id, now: started.addingTimeInterval(900))
            }
        }

        /// A run yesterday at 07:00, yoga three days ago and, when there is a finished workout, a strength session
        /// recorded inside it (linked: no XP of its own). Only when the athlete has no activities yet.
        static func seedActivities(_ database: AppDatabase, athleteId: UUID) async throws {
            guard try await ActivityRepository(database).activities(athleteId: athleteId).isEmpty else { return }
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            var activities: [(type: String, start: Date, seconds: Int, meters: Decimal?, heartRate: Int, kcal: Int)] = [
                ("RUNNING", today.addingTimeInterval(-86_400 + 7 * 3_600), 2_400, 8_200, 152, 520),
                ("YOGA", today.addingTimeInterval(-3 * 86_400 + 19 * 3_600), 1_500, nil, 98, 110),
            ]
            if let workout = try await ProgressService(database).history(athleteId: athleteId).sessions.last {
                activities.append(
                    ("STRENGTH_TRAINING", workout.startedAt.addingTimeInterval(300), 3_300, nil, 128, 410))
            }
            let seeds = activities
            try await database.writer.write { db in
                for activity in seeds {
                    try ImportedActivity(
                        id: UUIDv7.make(at: activity.start), athleteId: athleteId, source: "garmin",
                        externalId: "demo-\(activity.type)", activityType: activity.type, startedAt: activity.start,
                        durationSeconds: activity.seconds, distanceMeters: activity.meters,
                        averageHeartRate: activity.heartRate, calories: activity.kcal, createdAt: activity.start
                    ).insert(db)
                }
            }
        }
    }
#endif
