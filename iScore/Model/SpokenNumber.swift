import Foundation

/// Turns spoken number words into integers, in English or Spanish by the locale's language
/// (anything other than Spanish reads as English). Covers 0-999, the range a domino target or
/// score can reach. Pure logic: it knows nothing about games or players.
enum SpokenNumber {

    /// A single number from `token` ("200", "nine", "twenty-five"), or nil if it is not one.
    static func parse(_ token: String, locale: Locale) -> Int? {
        value(of: [token], locale: locale)
    }

    /// Every number in `words`, left to right, with the word indices each one consumed.
    /// Takes the longest run that forms one number, so "two hundred" is 200, not 2.
    static func scan(_ words: [String], locale: Locale) -> [(value: Int, range: Range<Int>)] {
        var hits: [(value: Int, range: Range<Int>)] = []
        var start = 0
        while start < words.count {
            var matched = false
            for end in stride(from: words.count, to: start, by: -1) {
                if let number = value(of: Array(words[start..<end]), locale: locale) {
                    hits.append((number, start..<end))
                    start = end
                    matched = true
                    break
                }
            }
            if !matched { start += 1 }
        }
        return hits
    }

    // MARK: - Grammar

    private enum Piece {
        case unit(Int)      // 1-9
        case small(Int)     // 10-19 (English), 10-29 (Spanish): stands alone, takes no unit after it
        case tens(Int)      // 20-90 (English), 30-90 (Spanish): may take a unit after it
        case hundreds(Int)  // a whole hundreds word: "ciento", "doscientos"
        case hundred        // English "hundred": multiplies the unit before it
        case connector      // "and" / "y"
    }

    /// The value of `words` read as exactly one number, or nil. Hyphenated words count as several.
    private static func value(of words: [String], locale: Locale) -> Int? {
        if words.count == 1, !words[0].isEmpty, words[0].allSatisfy({ $0.isASCII && $0.isNumber }) {
            return Int(words[0])
        }
        let table = locale.language.languageCode?.identifier == "es" ? spanish : english
        // Speech recognition returns accented Spanish ("dieciséis"); the tables are unaccented.
        let pieces = words.flatMap { word in
            word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: locale)
                .split(separator: "-").map(String.init)
        }.map { table[$0] }
        guard !pieces.isEmpty else { return nil }

        var hundreds = 0, rest = 0
        var pendingConnector = false
        for piece in pieces {
            guard let piece else { return nil }
            switch piece {
            case .unit(let n):
                guard rest == 0 || (rest >= 20 && rest % 10 == 0) else { return nil }
                rest += n
            case .small(let n), .tens(let n):
                guard rest == 0 else { return nil }
                rest = n
            case .hundreds(let n):
                guard hundreds == 0, rest == 0 else { return nil }
                hundreds = n
            case .hundred:
                guard hundreds == 0, (1...9).contains(rest) else { return nil }
                hundreds = rest * 100
                rest = 0
            case .connector:
                guard hundreds > 0 || rest >= 20, !pendingConnector else { return nil }
                pendingConnector = true
                continue
            }
            pendingConnector = false
        }
        return pendingConnector ? nil : hundreds + rest
    }

    // MARK: - Word tables

    private static let english: [String: Piece] = {
        var table: [String: Piece] = ["and": .connector, "hundred": .hundred]
        let units = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        for (i, word) in units.enumerated() { table[word] = .unit(i + 1) }
        let teens = ["ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
                     "seventeen", "eighteen", "nineteen"]
        for (i, word) in teens.enumerated() { table[word] = .small(10 + i) }
        let tens = ["twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
        for (i, word) in tens.enumerated() { table[word] = .tens(20 + 10 * i) }
        return table
    }()

    private static let spanish: [String: Piece] = {
        var table: [String: Piece] = ["y": .connector, "cien": .hundreds(100), "ciento": .hundreds(100)]
        let units = ["uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve"]
        for (i, word) in units.enumerated() { table[word] = .unit(i + 1) }
        let small = ["diez", "once", "doce", "trece", "catorce", "quince", "dieciseis", "diecisiete",
                     "dieciocho", "diecinueve", "veinte", "veintiuno", "veintidos", "veintitres",
                     "veinticuatro", "veinticinco", "veintiseis", "veintisiete", "veintiocho", "veintinueve"]
        for (i, word) in small.enumerated() { table[word] = .small(10 + i) }
        let tens = ["treinta", "cuarenta", "cincuenta", "sesenta", "setenta", "ochenta", "noventa"]
        for (i, word) in tens.enumerated() { table[word] = .tens(30 + 10 * i) }
        let hundreds = ["doscientos", "trescientos", "cuatrocientos", "quinientos", "seiscientos",
                        "setecientos", "ochocientos", "novecientos"]
        for (i, word) in hundreds.enumerated() { table[word] = .hundreds(200 + 100 * i) }
        return table
    }()
}
