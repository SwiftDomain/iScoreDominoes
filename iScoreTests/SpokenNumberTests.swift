import Foundation
import Testing
@testable import iScore

struct SpokenNumberTests {

    private let en = Locale(identifier: "en_US")
    private let es = Locale(identifier: "es_DO")

    @Test func parsesDigits() {
        #expect(SpokenNumber.parse("200", locale: en) == 200)
        #expect(SpokenNumber.parse("9", locale: es) == 9)
        #expect(SpokenNumber.parse("abc", locale: en) == nil)
        #expect(SpokenNumber.parse("", locale: en) == nil)
    }

    @Test func parsesEnglishWords() {
        #expect(SpokenNumber.parse("nine", locale: en) == 9)
        #expect(SpokenNumber.parse("twenty-five", locale: en) == 25)
    }

    @Test func parsesSpanishWords() {
        #expect(SpokenNumber.parse("nueve", locale: es) == 9)
        #expect(SpokenNumber.parse("veinticinco", locale: es) == 25)
        #expect(SpokenNumber.parse("doscientos", locale: es) == 200)
    }

    /// Speech recognition returns accented Spanish; the tables are unaccented.
    @Test func parsesAccentedSpanish() {
        #expect(SpokenNumber.parse("dieciséis", locale: es) == 16)
        #expect(SpokenNumber.parse("veintidós", locale: es) == 22)
        #expect(SpokenNumber.parse("veintitrés", locale: es) == 23)
    }

    @Test func scansCompoundsAcrossWords() {
        let hits = SpokenNumber.scan(["two", "hundred"], locale: en)
        #expect(hits.count == 1)
        #expect(hits[0].value == 200)
        #expect(hits[0].range == 0..<2)
    }

    @Test func scansSpanishCompounds() {
        let hits = SpokenNumber.scan(["ciento", "cincuenta"], locale: es)
        #expect(hits.map(\.value) == [150])
    }

    @Test func scansAccentedCompounds() {
        let hits = SpokenNumber.scan(["ciento", "veintidós"], locale: es)
        #expect(hits.count == 1)
        #expect(hits[0].value == 122)
        #expect(hits[0].range == 0..<2)
    }

    @Test func scansSeveralNumbersWithWordsBetween() {
        let hits = SpokenNumber.scan(["nine", "to", "two", "hundred"], locale: en)
        #expect(hits.map(\.value) == [9, 200])
        #expect(hits.map(\.range) == [0..<1, 2..<4])
    }

    @Test func scanFindsNothingInPlainWords() {
        #expect(SpokenNumber.scan(["me", "and", "carlos"], locale: en).isEmpty)
    }
}
