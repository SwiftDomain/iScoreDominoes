import Foundation
import Testing
@testable import iScore

struct PlayStreakTests {

    private let calendar = Calendar(identifier: .gregorian)

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 12))!
    }

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: today)!
    }

    private func streak(_ dates: [Date]) -> Int {
        PlayStreak.days(endingOn: today, playDates: dates, calendar: calendar)
    }

    @Test func countsThroughToday() {
        #expect(streak([daysAgo(0), daysAgo(1), daysAgo(2)]) == 3)
    }

    @Test func startsYesterdayWhenNoGameToday() {
        #expect(streak([daysAgo(1), daysAgo(2)]) == 2)
    }

    @Test func brokenStreakIsZero() {
        #expect(streak([daysAgo(3)]) == 0)
    }

    @Test func noGamesIsZero() {
        #expect(streak([]) == 0)
    }

    @Test func sameDayCountsOnce() {
        #expect(streak([today, today.addingTimeInterval(-3600)]) == 1)
    }
}
