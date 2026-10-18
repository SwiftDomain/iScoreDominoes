import Testing
@testable import iScore

struct ScoreEntryTests {

    @Test func typesNumber() {
        var entry = ScoreEntry()
        entry.append(3)
        entry.append(5)
        #expect(entry.digits == "35")
        #expect(entry.value == 35)
        #expect(entry.buttonTitle == "Add 35 points")
    }

    @Test func ignoresLeadingZero() {
        var entry = ScoreEntry()
        entry.append(0)
        #expect(entry.digits == "")
        #expect(entry.value == nil)

        entry.append(5)
        entry.append(0)
        #expect(entry.digits == "50")
    }

    @Test func capsAtThreeDigits() {
        var entry = ScoreEntry()
        for digit in [1, 2, 3, 4] { entry.append(digit) }
        #expect(entry.digits == "123")
        #expect(entry.value == 123)
    }

    @Test func deleteAndClear() {
        var entry = ScoreEntry()
        entry.deleteLast()
        #expect(entry.digits == "")

        entry.append(4)
        entry.append(2)
        entry.deleteLast()
        #expect(entry.digits == "4")

        entry.clear()
        #expect(entry.value == nil)
    }

    @Test func ignoresInvalidDigit() {
        var entry = ScoreEntry()
        entry.append(12)
        entry.append(-1)
        #expect(entry.digits == "")
    }

    @Test func takeReturnsValueOnlyOnce() {
        // A double-tap on Add must not save the round twice.
        var entry = ScoreEntry()
        entry.append(3)
        entry.append(5)
        #expect(entry.take() == 35)
        #expect(entry.take() == nil)
        #expect(entry.digits == "")
    }

    @Test func buttonTitles() {
        var entry = ScoreEntry()
        #expect(entry.buttonTitle == "Add points")
        entry.append(1)
        #expect(entry.buttonTitle == "Add 1 point")
    }

    @Test func saveTitles() {
        var entry = ScoreEntry()
        #expect(entry.title("Save") == "Save points")
        entry.append(1)
        #expect(entry.title("Save") == "Save 1 point")
        entry.append(0)
        #expect(entry.title("Save") == "Save 10 points")
    }

    /// Review Focus 3: a spoken value replaces what was typed. 3 + "twenty-five" is 25, never 325.
    @Test func settingAValueReplacesTheTypedDigits() {
        var entry = ScoreEntry()
        entry.append(3)
        entry.set(25)
        #expect(entry.digits == "25")
        #expect(entry.value == 25)
    }

    @Test func settingIgnoresValuesTheKeypadCouldNotHold() {
        var entry = ScoreEntry()
        entry.append(3)
        entry.set(0)
        #expect(entry.digits == "3")
        entry.set(-5)
        #expect(entry.digits == "3")
        entry.set(1000)
        #expect(entry.digits == "3")
        entry.set(999)
        #expect(entry.digits == "999")
    }

    /// A spoken value for the other team must not land in this sheet's entry.
    @Test func settingIsTheOnlyWayASpokenValueReachesTheEntry() {
        var entry = ScoreEntry()
        entry.append(2)
        entry.append(0)
        // The wrong-team path must leave the typed digits alone.
        #expect(entry.digits == "20")
        #expect(entry.value == 20)
    }
}
