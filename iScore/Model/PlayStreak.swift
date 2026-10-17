//
//  PlayStreak.swift
//  iScore
//
//  Day streak shown on Home: consecutive calendar days with at least one game.
//

import Foundation

enum PlayStreak {

    /// Counts back from `today` (or from yesterday if nothing was played today,
    /// so the streak survives until the day is over).
    static func days(endingOn today: Date, playDates: [Date], calendar: Calendar = .current) -> Int {
        let playedDays = Set(playDates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: today)

        if !playedDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var count = 0
        while playedDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
