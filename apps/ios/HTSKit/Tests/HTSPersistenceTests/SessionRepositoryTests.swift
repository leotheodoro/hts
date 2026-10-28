import Foundation
import GRDB
import HTSDomain
import Testing

@testable import HTSPersistence

@Suite struct SessionRepositoryTests {
    let utc = TimeZone(identifier: "UTC")!

    /// A plan with one arc and template A (Zercher Squat 4 × 6-6-3-3).
    func seeded() async throws -> (PlanFixture, TemplatePlan) {
        let fixture = try await PlanFixture()
        let arc = fixture.arc("Recrutamento", status: .current)
        _ = try await fixture.seedPlan(arc: arc)
        let plan = try #require(try await PlanRepository(fixture.database).plan(arcId: arc.id))
        return (fixture, try #require(plan.templates.first))
    }

    func set(_ session: Session, _ plan: TemplatePlan, number: Int, kg: Decimal, at: Date) -> LoggedSet {
        let planned = plan.blocks[0].exercises[0]
        return LoggedSet(
            id: UUIDv7.make(at: at), athleteId: session.athleteId, sessionId: session.id,
            prescribedExerciseId: planned.prescription.id, exerciseId: planned.exercise.id, setNumber: number,
            weightKg: kg, reps: 6, completed: true, completedAt: at, createdAt: at)
    }

    @Test func snapshotDoesNotChangeWhenThePlanIsEdited() async throws {
        let (fixture, plan) = try await seeded()
        let repository = SessionRepository(fixture.database)
        let session = try await repository.start(plan, now: fixture.now, timeZone: utc)

        var prescription = plan.blocks[0].exercises[0].prescription
        prescription.targets = [.fixed(10)]
        try await PlanRepository(fixture.database).save(prescription)

        let stored = try #require(try await repository.session(id: session.id))
        #expect(stored == session)
        #expect(stored.planSnapshot.blocks[0].exercises[0].targets == [.fixed(6), .fixed(6), .fixed(3), .fixed(3)])
        #expect(stored.planSnapshot.blocks[0].exercises[0].name == "Zercher Squat")
    }

    @Test func snapshotJSONUsesLowercaseIdsAndNulls() async throws {
        let (fixture, plan) = try await seeded()
        _ = try await SessionRepository(fixture.database).start(plan, now: fixture.now, timeZone: utc)
        let json = try #require(
            try await fixture.database.writer.read { db in
                try String.fetchOne(db, sql: "SELECT plan_snapshot FROM session")
            })
        #expect(json.contains(plan.template.id.uuidString.lowercased()))
        #expect(!json.contains(plan.template.id.uuidString))
        #expect(json.contains(#""focus":null"#))
    }

    @Test func allowsOnlyOneSessionInProgress() async throws {
        let (fixture, plan) = try await seeded()
        let repository = SessionRepository(fixture.database)
        let first = try await repository.start(plan, now: fixture.now, timeZone: utc)
        await #expect(throws: DatabaseError.self) {
            _ = try await repository.start(plan, now: fixture.now.addingTimeInterval(60), timeZone: utc)
        }
        #expect(try await repository.inProgress(athleteId: fixture.athlete.id) == first)
        _ = try await repository.finish(sessionId: first.id, now: fixture.now.addingTimeInterval(3600))
        #expect(try await repository.inProgress(athleteId: fixture.athlete.id) == nil)
        _ = try await repository.start(plan, now: fixture.now.addingTimeInterval(7200), timeZone: utc)
    }

    @Test func storesExactDecimalLoadsAndRestoresSets() async throws {
        let (fixture, plan) = try await seeded()
        let repository = SessionRepository(fixture.database)
        let session = try await repository.start(plan, now: fixture.now, timeZone: utc)
        let logged = set(session, plan, number: 1, kg: Decimal(string: "62.5")!, at: fixture.now)
        try await repository.save(logged)

        let stored = try await fixture.database.writer.read { db in
            try String.fetchOne(db, sql: "SELECT weight_kg FROM logged_set WHERE id = ?", arguments: [logged.id.sql])
        }
        #expect(stored == "62.5")
        #expect(try await repository.sets(sessionId: session.id).contains(logged))

        try await repository.deleteSet(id: logged.id, now: fixture.now)
        #expect(try await !repository.sets(sessionId: session.id).contains(logged))
    }

    @Test func storesFightRoundsWithDecimalStringWeights() async throws {
        let (fixture, plan) = try await seeded()
        let repository = SessionRepository(fixture.database)
        let session = try await repository.start(plan, now: fixture.now, timeZone: utc)
        let round = LoggedRound(
            id: UUIDv7.make(), athleteId: session.athleteId, sessionId: session.id, blockId: plan.blocks[0].block.id,
            roundsCompleted: 3,
            weights: [.init(exerciseId: plan.blocks[0].exercises[0].exercise.id, weightKg: Decimal(string: "24.5")!)],
            createdAt: fixture.now)
        try await repository.save(round)
        #expect(try await repository.rounds(sessionId: session.id) == [round])
        let json = try await fixture.database.writer.read { db in
            try String.fetchOne(db, sql: "SELECT weights FROM logged_round")
        }
        #expect(json?.contains(#""weightKg":"24.5""#) == true)
    }

    @Test func numbersAreDerivedAndRenumberAfterDelete() async throws {
        let (fixture, plan) = try await seeded()
        let repository = SessionRepository(fixture.database)
        var sessions: [Session] = []
        for day in 0..<3 {
            let start = fixture.now.addingTimeInterval(Double(day) * 86_400)
            let session = try await repository.start(plan, now: start, timeZone: utc)
            sessions.append(try await repository.finish(sessionId: session.id, now: start.addingTimeInterval(3600)))
        }
        #expect(try await repository.number(of: sessions[2]) == .init(global: 3, inArc: 3))

        try await repository.delete(sessionId: sessions[0].id, now: fixture.now)
        #expect(try await repository.number(of: sessions[2]) == .init(global: 2, inArc: 2))
        #expect(
            try await repository.sessions(athleteId: fixture.athlete.id).map(\.id) == [sessions[2].id, sessions[1].id])
    }

    @Test func countResetOnlyAffectsTheArcNumber() async throws {
        let (fixture, plan) = try await seeded()
        let repository = SessionRepository(fixture.database)
        let first = try await repository.start(plan, now: fixture.now, timeZone: utc)
        _ = try await repository.finish(sessionId: first.id, now: fixture.now.addingTimeInterval(60))

        var arc = try #require(try await PlanRepository(fixture.database).currentArc(athleteId: fixture.athlete.id))
        arc.countResetAt = fixture.now.addingTimeInterval(3600)
        try await PlanRepository(fixture.database).save(arc)

        let second = try await repository.start(plan, now: fixture.now.addingTimeInterval(7200), timeZone: utc)
        #expect(try await repository.number(of: second) == .init(global: 2, inArc: 1))
    }

    @Test func deletingASessionDeletesItsSets() async throws {
        let (fixture, plan) = try await seeded()
        let repository = SessionRepository(fixture.database)
        let session = try await repository.start(plan, now: fixture.now, timeZone: utc)
        try await repository.save(set(session, plan, number: 1, kg: 60, at: fixture.now))
        try await repository.delete(sessionId: session.id, now: fixture.now)
        #expect(try await repository.session(id: session.id) == nil)
        #expect(try await repository.sets(sessionId: session.id).isEmpty)
        #expect(try await repository.inProgress(athleteId: fixture.athlete.id) == nil)
    }

    @Test func localDateFollowsTheDeviceTimeZone() async throws {
        let (fixture, plan) = try await seeded()
        // Already the 29th in UTC, still the 28th in São Paulo.
        let lateUTC = Date(timeIntervalSince1970: 1_761_701_400)  // 2025-10-29T01:30:00Z
        let session = try await SessionRepository(fixture.database).start(
            plan, now: lateUTC, timeZone: TimeZone(identifier: "America/Sao_Paulo")!)
        #expect(session.localDate == LocalDate("2025-10-28"))
    }

    @Test func startCreatesOneRowPerMinimumSet() async throws {
        let (fixture, plan) = try await seeded()
        let repository = SessionRepository(fixture.database)
        let session = try await repository.start(plan, now: fixture.now, timeZone: utc)
        let sets = try await repository.sets(sessionId: session.id)
        #expect(sets.map(\.setNumber) == [1, 2, 3, 4])
        #expect(sets.allSatisfy { !$0.completed })

        let extra = try await repository.addSet(
            to: session, exercise: session.planSnapshot.blocks[0].exercises[0], now: fixture.now)
        #expect(extra.setNumber == 5)
    }

    @Test func previousSetsComeFromTheLastCompletedSessionOfTheTemplate() async throws {
        let (fixture, plan) = try await seeded()
        let repository = SessionRepository(fixture.database)
        let first = try await repository.start(plan, now: fixture.now, timeZone: utc)
        var rows = try await repository.sets(sessionId: first.id)
        rows[0].weightKg = 60
        rows[0].reps = 6
        rows[0].completed = true
        try await repository.save(rows[0])
        _ = try await repository.finish(sessionId: first.id, now: fixture.now.addingTimeInterval(3600))
        #expect(try await repository.lastLetter(arcId: first.arcId) == "A")

        let second = try await repository.start(plan, now: fixture.now.addingTimeInterval(86_400), timeZone: utc)
        let previous = try await repository.previousSets(for: second)
        let exerciseId = plan.blocks[0].exercises[0].exercise.id
        #expect(previous[exerciseId]?[1]?.summary(unit: .reps) == "60 × 6")
        #expect(previous[exerciseId]?[2] == nil)
        #expect(try await repository.previousSets(for: first).isEmpty)
    }
}

@Suite struct FightRoundTests {
    @Test func roundRecordIsCreatedOnceAndUpdated() async throws {
        let fixture = try await PlanFixture()
        let arc = fixture.arc("Torneio", status: .current)
        let (template, exercise) = try await fixture.seedPlan(arc: arc)
        let plan = try #require(
            try await PlanRepository(fixture.database).plan(arcId: arc.id)?.templates.first {
                $0.template.id == template.id
            })
        let repository = SessionRepository(fixture.database)
        let session = try await repository.start(plan, now: fixture.now, timeZone: TimeZone(identifier: "UTC")!)
        let block = session.planSnapshot.blocks[0]

        var round = try await repository.round(for: session, block: block, now: fixture.now)
        #expect(try await repository.round(for: session, block: block, now: fixture.now) == round)
        round.roundsCompleted = 4
        round.weights = [.init(exerciseId: exercise.id, weightKg: 24)]
        try await repository.save(round)
        #expect(try await repository.rounds(sessionId: session.id) == [round])
    }
}
