import Foundation
import Testing

@testable import HTSDomain

@Suite struct RestTimerTests {
    let start = Date(timeIntervalSince1970: 1_793_000_000)

    @Test func countsDownFromTheEndInstant() {
        let timer = RestTimer(startedAt: start, seconds: 90)
        #expect(timer.remaining(at: start.addingTimeInterval(18)) == 72)
        #expect(RestTimer.format(timer.remaining(at: start.addingTimeInterval(18))) == "1:12")
        #expect(timer.progress(at: start.addingTimeInterval(45)) == 0.5)
        #expect(timer.isFinished(at: start.addingTimeInterval(90)))
        #expect(timer.remaining(at: start.addingTimeInterval(300)) == 0)
    }

    @Test func adjustsBy15SecondsButNotIntoThePast() {
        var timer = RestTimer(startedAt: start, seconds: 30)
        timer.adjust(by: RestTimer.step, now: start)
        #expect(timer.remaining(at: start) == 45)
        timer.adjust(by: -60, now: start.addingTimeInterval(10))
        #expect(timer.isFinished(at: start.addingTimeInterval(10)))
    }

    @Test func exerciseRestWinsOverTheDefault() {
        #expect(RestTimer.seconds(exerciseRest: 30, athleteDefault: 90) == 30)
        #expect(RestTimer.seconds(exerciseRest: nil, athleteDefault: 90) == 90)
    }

    @Test func formatRoundsUpPartialSeconds() {
        #expect(RestTimer.format(0.2) == "0:01")
        #expect(RestTimer.format(0) == "0:00")
        #expect(RestTimer.format(125) == "2:05")
    }
}
