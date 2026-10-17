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

    @Test func buttonTitles() {
        var entry = ScoreEntry()
        #expect(entry.buttonTitle == "Add points")
        entry.append(1)
        #expect(entry.buttonTitle == "Add 1 point")
    }
}
