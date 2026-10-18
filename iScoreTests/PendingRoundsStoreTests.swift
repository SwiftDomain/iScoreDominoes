//
//  PendingRoundsStoreTests.swift
//  iScoreTests
//
//  The handoff file between the widget and the app. Ordering, surviving a
//  tap that lands mid-drain, and never being poisoned by a half-written
//  line are the properties the Lock Screen score depends on.
//

import Foundation
import Testing
@testable import iScore

struct PendingRoundsStoreTests {

    private func tempStore() -> PendingRoundsStore {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return PendingRoundsStore(url: dir.appendingPathComponent("pending-rounds.jsonl"))
    }

    private func round(_ points: Int, _ team: TeamSide = .team1, game: UUID = UUID()) -> PendingRound {
        PendingRound(id: UUID(), gameID: game, action: .add(points: points, team: team), date: Date())
    }

    @Test func loadingAnAbsentFileIsEmptyNotAnError() throws {
        #expect(try tempStore().load().isEmpty)
    }

    @Test func appendsKeepFileOrder() throws {
        let store = tempStore()
        let game = UUID()
        let first = round(25, .team1, game: game)
        let second = round(30, .team2, game: game)
        let third = PendingRound(id: UUID(), gameID: game, action: .undo, date: Date())
        try store.append(first)
        try store.append(second)
        try store.append(third)

        let loaded = try store.load()
        #expect(loaded.map(\.id) == [first.id, second.id, third.id])
        #expect(loaded[0].action == .add(points: 25, team: .team1))
        #expect(loaded[1].action == .add(points: 30, team: .team2))
        #expect(loaded[2].action == .undo)
    }

    @Test func drainReturnsEverythingAndEmptiesTheFile() throws {
        let store = tempStore()
        try store.append(round(10))
        try store.append(round(20))

        #expect(try store.drain().map(\.action) == [.add(points: 10, team: .team1),
                                                    .add(points: 20, team: .team1)])
        #expect(try store.load().isEmpty)
        #expect(try store.drain().isEmpty)
    }

    /// Review Focus 1: a tap that lands after the drain has read must not be
    /// thrown away by the truncation that follows it.
    @Test func anAppendDuringADrainSurvives() throws {
        let store = tempStore()
        try store.append(round(10))
        let readBytes = try Data(contentsOf: store.url).count

        try store.append(round(99))
        try store.truncate(toOffset: UInt64(readBytes))

        let left = try store.load()
        #expect(left.count == 1)
        #expect(left[0].action == .add(points: 99, team: .team1))
    }

    /// Review Focus 4.
    @Test func corruptLinesAreSkippedAndTheRestStillLoad() throws {
        let store = tempStore()
        try store.append(round(10))
        let handle = try FileHandle(forWritingTo: store.url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{not json\n".utf8))
        try handle.close()
        try store.append(round(20))

        let loaded = try store.load()
        #expect(loaded.map(\.action) == [.add(points: 10, team: .team1),
                                         .add(points: 20, team: .team1)])
    }

    @Test func aTruncatedFinalLineIsSkipped() throws {
        let store = tempStore()
        try store.append(round(10))
        let handle = try FileHandle(forWritingTo: store.url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"id\":\"half".utf8))   // a kill mid-write
        try handle.close()

        #expect(try store.load().map(\.action) == [.add(points: 10, team: .team1)])
        _ = try store.drain()
        #expect(try store.load().isEmpty)
    }

    @Test func teamSideBridgesToTeam() {
        #expect(TeamSide.team1.team == .team1)
        #expect(TeamSide.team2.team == .team2)
        #expect(TeamSide(.team1) == .team1)
        #expect(TeamSide(.none) == nil)
    }
}
