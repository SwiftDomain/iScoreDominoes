import Foundation
import Testing
@testable import iScore

struct SpectateHostTests {

    private let code = JoinCode(typed: "K7MQ")!

    // MARK: - Who gets in (Review Focus 1)

    @Test func theRightCodeIsLetIn() {
        #expect(SpectatePolicy.acceptsInvitation(context: SpectatePolicy.invitationContext(for: code), code: code))
    }

    @Test func anythingElseIsTurnedAway() {
        let other = JoinCode(typed: "ABCD")!
        #expect(!SpectatePolicy.acceptsInvitation(context: SpectatePolicy.invitationContext(for: other), code: code))
        #expect(!SpectatePolicy.acceptsInvitation(context: nil, code: code))
        #expect(!SpectatePolicy.acceptsInvitation(context: Data(), code: code))
        #expect(!SpectatePolicy.acceptsInvitation(context: Data("k7mq".utf8), code: code))
    }

    @Test func guestsOnlyApproachTheirOwnGame() {
        let info = SpectatePolicy.discoveryInfo(for: code)
        #expect(SpectatePolicy.matches(discoveryInfo: info, code: code))
        #expect(!SpectatePolicy.matches(discoveryInfo: info, code: JoinCode(typed: "ABCD")!))
        #expect(!SpectatePolicy.matches(discoveryInfo: nil, code: code))
    }

    // MARK: - What gets sent (Review Focus 5)

    private func shared(_ game: Game) -> SpectatePolicy.SharedGame { .init(game) }

    @Test func theSharedGameIsPublishedWhilePlayingAndWhenItEnds() {
        let game = makeTestGame()
        let current = shared(game)
        #expect(SpectatePolicy.shouldPublish(game, shared: current))
        game.state = .finished
        #expect(SpectatePolicy.shouldPublish(game, shared: current))
    }

    @Test func nothingSharedYetTakesAPlayingGameOnly() {
        #expect(SpectatePolicy.shouldPublish(makeTestGame(), shared: nil))
        #expect(!SpectatePolicy.shouldPublish(makeTestGame(rows: demoGameRows, state: .finished), shared: nil))
    }

    /// Opening a finished game from history while sharing must not take over
    /// the broadcast — not even by opening the share sheet from it.
    @Test func anOldFinishedGameIsNeverPublished() {
        let current = shared(makeTestGame())
        let old = makeTestGame(rows: demoGameRows, state: .finished)
        #expect(!SpectatePolicy.shouldPublish(old, shared: current))
        #expect(SpectatePolicy.shared(afterPublishing: old, current: current) == current)
    }

    /// An unfinished game abandoned weeks ago is still `.playing`; opening it
    /// must not steal the broadcast from tonight's game.
    @Test func anOlderPlayingGameDoesNotTakeOverAPlayingSharedGame() {
        let tonight = makeTestGame(timestamp: .now)
        let abandoned = makeTestGame(timestamp: .now.addingTimeInterval(-86_400 * 30))
        #expect(!SpectatePolicy.shouldPublish(abandoned, shared: shared(tonight)))
    }

    /// The next game of the night is newer, so guests follow it.
    @Test func theNextGameTakesOver() {
        let first = makeTestGame(timestamp: .now.addingTimeInterval(-3_600))
        let next = makeTestGame(timestamp: .now)
        #expect(SpectatePolicy.shouldPublish(next, shared: shared(first)))
        first.state = .finished
        #expect(SpectatePolicy.shared(afterPublishing: next, current: shared(first))?.id == next.id)
    }

    // MARK: - Staying awake (finding 6)

    @Test func theHostStaysAwakeOnlyWhileTheSharedGameIsPlaying() {
        let game = makeTestGame()
        #expect(SpectatePolicy.keepsHostAwake(shared(game)))
        game.state = .finished
        #expect(!SpectatePolicy.keepsHostAwake(shared(game)))
        #expect(!SpectatePolicy.keepsHostAwake(nil))
    }

    // MARK: - Inviting (finding 2)

    @Test func aGuestInvitesOnlyWhenIdleAndTheCodeMatches() {
        let info = SpectatePolicy.discoveryInfo(for: code)
        #expect(SpectatePolicy.shouldInvite(discoveryInfo: info, code: code, busy: false))
        #expect(!SpectatePolicy.shouldInvite(discoveryInfo: info, code: code, busy: true))
        #expect(!SpectatePolicy.shouldInvite(discoveryInfo: info, code: JoinCode(typed: "ABCD")!, busy: false))
    }

    // MARK: - Copy

    @Test func watchingCountReadsNaturally() {
        #expect(String(localized: SpectatePolicy.watchingLabel(0)) == "Nobody watching yet")
        #expect(String(localized: SpectatePolicy.watchingLabel(1)) == "1 watching")
        #expect(String(localized: SpectatePolicy.watchingLabel(3)) == "3 watching")
        #expect(localized(SpectatePolicy.watchingLabel(0), in: "es") == "Nadie mirando todavía")
        #expect(localized(SpectatePolicy.watchingLabel(1), in: "es") == "1 mirando")
        #expect(localized(SpectatePolicy.watchingLabel(3), in: "es") == "3 mirando")
    }
}
