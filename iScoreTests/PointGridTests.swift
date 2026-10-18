//
//  PointGridTests.swift
//  iScoreTests
//
//  A Lock Screen button cannot show a keypad, so the activity carries the
//  handful of values that actually come up. Chosen by frequency, shown in
//  ascending order so the buttons never move under the user's thumb.
//

import Foundation
import Testing
@testable import iScore

struct PointGridTests {

    @Test func defaultsAreSixValuesPerGameType() {
        #expect(PointGrid.defaults(for: .six).count == PointGrid.size)
        #expect(PointGrid.defaults(for: .nine).count == PointGrid.size)
        #expect(PointGrid.defaults(for: .six).allSatisfy { $0 > 0 && $0 % 5 == 0 })
        #expect(PointGrid.defaults(for: .nine).allSatisfy { $0 > 0 && $0 % 5 == 0 })
        #expect(PointGrid.defaults(for: .six) == PointGrid.defaults(for: .six).sorted())
        #expect(PointGrid.defaults(for: .nine) == PointGrid.defaults(for: .nine).sorted())
    }

    @Test func doubleNineRunsHigherThanDoubleSix() {
        #expect(PointGrid.defaults(for: .nine).max()! > PointGrid.defaults(for: .six).max()!)
    }

    @Test func noHistoryGivesTheDefaults() {
        #expect(PointGrid.values(for: .six, history: []) == PointGrid.defaults(for: .six))
    }

    @Test func aFrequentUnusualValueEarnsASlot() {
        let grid = PointGrid.values(for: .six, history: Array(repeating: 47, count: 20))
        #expect(grid.contains(47))
        #expect(grid.count == PointGrid.size)
        #expect(grid == grid.sorted())
    }

    @Test func aRareValueDoesNotDisplaceADefault() {
        #expect(PointGrid.values(for: .six, history: [47]) == PointGrid.defaults(for: .six))
    }

    @Test func theGridIsAlwaysFullAndFreeOfDuplicates() {
        let grid = PointGrid.values(for: .nine, history: [30, 30, 30, 30, 30])
        #expect(grid.count == PointGrid.size)
        #expect(Set(grid).count == PointGrid.size)
    }

    @Test func garbageHistoryIsIgnored() {
        #expect(PointGrid.values(for: .six, history: [0, -5, 0, 0, 0, 0, 0, 0]) == PointGrid.defaults(for: .six))
    }

    @Test func aSmallerLimitStillReturnsTheMostCommonValues() {
        let grid = PointGrid.values(for: .six, history: Array(repeating: 25, count: 10), limit: 3)
        #expect(grid.count == 3)
        #expect(grid.contains(25))
    }
}
