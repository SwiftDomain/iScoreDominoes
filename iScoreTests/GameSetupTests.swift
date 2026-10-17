import Foundation
import Testing
@testable import iScore

struct GameTypeSetupTests {

    @Test func titles() {
        #expect(GameType.six.title == "Double 6")
        #expect(GameType.nine.title == "Double 9")
    }

    @Test func targets() {
        #expect(GameType.six.targetRange == 10...100)
        #expect(GameType.nine.targetRange == 10...200)
        #expect(GameType.six.defaultTarget == 20)
        #expect(GameType.nine.defaultTarget == 100)
    }

    /// A target of 0 ended the game on the first score; old settings may still hold it.
    @Test func clampsTargets() {
        #expect(GameType.nine.clampedTarget(0) == 10)
        #expect(GameType.nine.clampedTarget(250) == 200)
        #expect(GameType.six.clampedTarget(150) == 100)
        #expect(GameType.nine.clampedTarget(104) == 100)
        #expect(GameType.nine.clampedTarget(130) == 130)
    }

    @Test func stepsTargets() {
        #expect(GameType.nine.steppedTarget(100, by: 1) == 110)
        #expect(GameType.nine.steppedTarget(100, by: -1) == 90)
        #expect(GameType.nine.steppedTarget(200, by: 1) == 200)
        #expect(GameType.six.steppedTarget(10, by: -1) == 10)
    }
}

struct PlayerLineupTests {

    private func lineup(_ names: [String]) -> PlayerLineup {
        var lineup = PlayerLineup()
        for (seat, name) in names.enumerated() { lineup.names[seat] = name }
        return lineup
    }

    @Test func emptyLineup() {
        let empty = PlayerLineup()
        #expect(!empty.isComplete)
        #expect(empty.hint == "Add 4 more players to start")
    }

    @Test func oneSeatLeft() {
        let lineup = lineup(["Ana", "Luis", "Rafa", "  "])
        #expect(!lineup.isComplete)
        #expect(lineup.hint == "Add 1 more player to start")
    }

    @Test func duplicatesAreCaseInsensitive() {
        let lineup = lineup(["Ana", "Luis", "Rafa", "ana "])
        #expect(!lineup.isComplete)
        #expect(lineup.hint == "Pick 4 different players")
    }

    @Test func completeLineup() {
        let lineup = lineup(["Ana", " Luis", "Rafa", "Mia"])
        #expect(lineup.isComplete)
        #expect(lineup.hint == nil)
        #expect(lineup.names(for: .team1) == ["Ana", "Luis"])
        #expect(lineup.names(for: .team2) == ["Rafa", "Mia"])
    }

    @Test func seats() {
        #expect(PlayerLineup.seat(team: .team1, position: 0) == 0)
        #expect(PlayerLineup.seat(team: .team1, position: 1) == 1)
        #expect(PlayerLineup.seat(team: .team2, position: 0) == 2)
        #expect(PlayerLineup.seat(team: .team2, position: 1) == 3)
        #expect(PlayerSeat(team: .team2, position: 1).id == 3)
        #expect(PlayerSeat(team: .team2, position: 1).title == "Team 2 · Player 2")
    }

    @Test func pickedNamesSkipTheSeatBeingEdited() {
        let lineup = lineup(["Ana", "Luis", "Rafa", ""])
        #expect(lineup.pickedNames(excludingSeat: 0) == ["Luis", "Rafa"])
        #expect(lineup.pickedNames(excludingSeat: 3) == ["Ana", "Luis", "Rafa"])
    }
}

struct PlayerNameTests {

    @Test func limitsLength() {
        #expect(PlayerName.limited("Maximiliano Andres") == "Maximiliano And")
        #expect(PlayerName.limited("Ana") == "Ana")
    }

    @Test func resolvesToAnExistingSpelling() {
        #expect(PlayerName.resolve(" ana ", existing: ["Ana", "Luis"]) == "Ana")
        #expect(PlayerName.resolve("Mia", existing: ["Ana"]) == "Mia")
        #expect(PlayerName.resolve("   ", existing: ["Ana"]) == "")
    }

    @Test func matchesSearch() {
        #expect(PlayerName.matches("Camila", query: "mi"))
        #expect(PlayerName.matches("Mia", query: ""))
        #expect(PlayerName.matches("Mia", query: "  "))
        #expect(!PlayerName.matches("Ana", query: "mi"))
    }

    @Test func sameNameIgnoresCaseAndSpaces() {
        #expect(PlayerName.isSame("Ana", " ana"))
        #expect(!PlayerName.isSame("Ana", "Anabel"))
    }
}

struct GameDefaultsTests {

    private func withDefaults(_ values: [String: Any], _ body: (UserDefaults) -> Void) {
        let suite = "GameDefaultsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        values.forEach { defaults.set($1, forKey: $0) }
        body(defaults)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func fallsBackToDoubleNine() {
        withDefaults([:]) { defaults in
            let loaded = GameDefaults.load(from: defaults)
            #expect(loaded.type == .nine)
            #expect(loaded.target == 100)
        }
    }

    @Test func readsSettings() {
        withDefaults([GameDefaults.typeKey: "six", GameDefaults.targetKey: 50.0]) { defaults in
            let loaded = GameDefaults.load(from: defaults)
            #expect(loaded.type == .six)
            #expect(loaded.target == 50)
        }
    }

    /// The old Settings slider allowed 0.
    @Test func clampsAStoredZero() {
        withDefaults([GameDefaults.typeKey: "nine", GameDefaults.targetKey: 0.0]) { defaults in
            #expect(GameDefaults.load(from: defaults).target == 10)
        }
    }

    @Test func ignoresAnUnknownType() {
        withDefaults([GameDefaults.typeKey: "twelve"]) { defaults in
            #expect(GameDefaults.load(from: defaults).type == .nine)
        }
    }
}

struct OwnerIdentityTests {

    /// Each test names its own suite and wipes it before and after, so nothing leaks
    /// between tests or into the app's real defaults.
    private func withSuite(_ name: String, _ body: (UserDefaults) -> Void) {
        let suite = "OwnerIdentityTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        body(defaults)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func loadsNothingByDefault() {
        withSuite("empty") { defaults in
            #expect(OwnerIdentity.load(from: defaults) == nil)
        }
    }

    @Test func loadsTheStoredName() {
        withSuite("stored") { defaults in
            defaults.set("Ana", forKey: OwnerIdentity.nameKey)
            #expect(OwnerIdentity.load(from: defaults) == "Ana")
        }
    }

    /// "Nobody" in Settings stores an empty string.
    @Test func treatsABlankStoredNameAsNobody() {
        withSuite("blank") { defaults in
            defaults.set("  ", forKey: OwnerIdentity.nameKey)
            #expect(OwnerIdentity.load(from: defaults) == nil)
        }
    }

    @Test func resolvesAgainstSavedPlayers() {
        #expect(OwnerIdentity.resolve("ana", known: ["Ana", "Luis"]) == "Ana")
        #expect(OwnerIdentity.resolve("Ana", known: ["Ana", "Luis"]) == "Ana")
    }

    @Test func forgetsADeletedPlayer() {
        #expect(OwnerIdentity.resolve("Tito", known: ["Ana", "Luis"]) == nil)
        #expect(OwnerIdentity.resolve(nil, known: ["Ana"]) == nil)
    }
}
