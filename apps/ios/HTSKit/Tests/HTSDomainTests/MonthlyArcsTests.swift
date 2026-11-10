import Foundation
import Testing

@testable import HTSDomain

/// Monthly arcs (#210): locked until the season's initial arcs are done, then all open; the current one follows
/// the calendar month.
@Suite struct MonthlyArcsTests {
    let athlete = UUID()
    let season = UUID()

    func arc(_ position: Int, _ status: ArcStatus, months: [Int]? = nil, kind: ArcKind = .normal) -> Arc {
        Arc(
            id: UUID(), athleteId: athlete, seasonId: season, name: "\(position)", kind: kind, weeks: 2,
            startDate: nil, status: status, position: position, months: months, createdAt: .now)
    }

    @Test func monthlyArcsStayLockedWhileAnInitialArcIsOpen() {
        let arcs = [arc(0, .completed), arc(1, .current), arc(2, .queued, months: [1, 2]), arc(3, .queued, months: [3])]
        #expect(!MonthlyArcs.inMonthlyPhase(arcs))
        #expect(arcs.allSatisfy { !MonthlyArcs.isOpen($0, in: arcs, seasonActive: true) })
        #expect(MonthlyArcs.current(in: arcs, month: 1) == nil)
    }

    @Test func everyMonthOpensOnceTheInitialArcsAreDone() {
        let arcs = [arc(0, .completed), arc(1, .completed), arc(2, .queued, months: [1, 2]), arc(3, .queued, months: [3])]
        #expect(MonthlyArcs.inMonthlyPhase(arcs))
        #expect(MonthlyArcs.isOpen(arcs[2], in: arcs, seasonActive: true))
        #expect(MonthlyArcs.isOpen(arcs[3], in: arcs, seasonActive: true))
        #expect(!MonthlyArcs.isOpen(arcs[0], in: arcs, seasonActive: true))
    }

    @Test func nothingIsOpenInAnInactiveSeason() {
        let arcs = [arc(0, .completed), arc(1, .queued, months: [1])]
        #expect(!MonthlyArcs.isOpen(arcs[1], in: arcs, seasonActive: false))
    }

    @Test func aCompletedMonthIsNotOpen() {
        let arcs = [arc(0, .completed), arc(1, .completed, months: [1])]
        #expect(!MonthlyArcs.isOpen(arcs[1], in: arcs, seasonActive: true))
    }

    @Test func aSeasonWithoutMonthsHasNoMonthlyPhase() {
        let arcs = [arc(0, .completed), arc(1, .completed)]
        #expect(!MonthlyArcs.inMonthlyPhase(arcs))
    }

    /// Manutenção arcs never hold the phase back.
    @Test func fillerArcsDoNotCount() {
        let arcs = [arc(0, .completed), arc(1, .queued, kind: .filler), arc(2, .queued, months: [5])]
        #expect(MonthlyArcs.inMonthlyPhase(arcs))
    }

    @Test func theCurrentArcIsTheOneOfTheCalendarMonth() {
        let arcs = [
            arc(0, .completed), arc(1, .queued, months: [1, 2]), arc(2, .queued, months: [11, 12]),
            arc(3, .queued, months: [10]),
        ]
        #expect(MonthlyArcs.current(in: arcs, month: 12)?.position == 2)
        #expect(MonthlyArcs.current(in: arcs, month: 10)?.position == 3)
    }

    /// No month covers the calendar (or it is completed): the first open month.
    @Test func otherwiseTheFirstOpenMonth() {
        let arcs = [
            arc(0, .completed), arc(1, .completed, months: [11]), arc(2, .queued, months: [3, 4]),
            arc(3, .queued, months: [1, 2]),
        ]
        #expect(MonthlyArcs.current(in: arcs, month: 11)?.position == 2)
        #expect(MonthlyArcs.current(in: arcs, month: 7)?.position == 2)
    }

    @Test func noCurrentArcWhenEveryMonthIsDone() {
        let arcs = [arc(0, .completed), arc(1, .completed, months: [1])]
        #expect(MonthlyArcs.current(in: arcs, month: 1) == nil)
    }

    /// The months a seed lists, in the arc row: "meses 1 e 2" is `[1, 2]`; an empty list is no months.
    @Test func anEmptyListIsNotMonthly() {
        #expect(!arc(0, .queued, months: []).isMonthly)
        #expect(arc(0, .queued, months: [4]).isMonthly)
        #expect(!arc(0, .queued).isMonthly)
    }
}
