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

    @Test func theSharedGameIsPublishedWhilePlayingAndWhenItEnds() {
        let game = makeTestGame()
        #expect(SpectatePolicy.shouldPublish(game, sharedGameID: game.id))
        game.state = .finished
        #expect(SpectatePolicy.shouldPublish(game, sharedGameID: game.id))
    }

    @Test func aNewGameIsPublishedAndAnOldOneNeverIs() {
        let shared = makeTestGame()
        let next = makeTestGame()
        let old = makeTestGame(rows: demoGameRows, state: .finished)
        #expect(SpectatePolicy.shouldPublish(next, sharedGameID: shared.id))
        #expect(!SpectatePolicy.shouldPublish(old, sharedGameID: shared.id))
    }

    @Test func theSharedGameFollowsOnlyWhatIsPublished() {
        let shared = makeTestGame()
        let next = makeTestGame()
        let old = makeTestGame(rows: demoGameRows, state: .finished)
        #expect(SpectatePolicy.sharedGameID(afterPublishing: old, current: shared.id) == shared.id)
        #expect(SpectatePolicy.sharedGameID(afterPublishing: next, current: shared.id) == next.id)
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
