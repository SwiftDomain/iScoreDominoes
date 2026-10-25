//
//  PresetMatcher.swift
//  iScore
//
//  "Start Friday night": a spoken phrase that names a preset. Checked before
//  the free-form game parser, and deliberately strict — a preset matches only
//  when the phrase is its name plus filler, never because the name appears
//  somewhere in a description ("nine, two hundred, Ana and Luis…" is not the
//  "Ana" preset).
//

import Foundation

enum PresetMatcher {

    /// The preset this phrase names; the longest name wins when several do.
    /// A name matches when its words appear as one unbroken run in the phrase
    /// and every other word is filler — so "juguemos el viernes por la noche"
    /// finds "Viernes por la noche", while a description that merely contains
    /// a preset's name still has words left over and finds nothing.
    static func match(_ transcript: String, presets: [PresetSetup]) -> PresetSetup? {
        let said = fold(transcript)
        return presets
            .filter { names(fold($0.name), in: said) }
            .max { fold($0.name).count < fold($1.name).count }
    }

    private static func names(_ name: [String], in said: [String]) -> Bool {
        guard !name.isEmpty, name.count <= said.count else { return false }
        for start in 0...(said.count - name.count) where Array(said[start..<start + name.count]) == name {
            let rest = said[..<start] + said[(start + name.count)...]
            if rest.allSatisfy(fillerWords.contains) { return true }
        }
        return false
    }

    /// Lowercased, accents stripped, curly apostrophes made straight (speech
    /// and smart punctuation both write "Let’s"), other punctuation turned into
    /// spaces, split into words.
    static func fold(_ text: String) -> [String] {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "\u{2019}", with: "'")
        let spaced = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "'" ? Character($0) : " " }
        return String(spaced).split(separator: " ").map(String.init)
    }

    /// Words around a preset's name that only ask for it to start.
    private static let fillerWords: Set<String> = [
        // English
        "start", "play", "begin", "lets", "let's", "new", "game", "the", "a", "preset", "please", "our", "usual",
        // Spanish (already folded: no accents)
        "empieza", "empezar", "empecemos", "comienza", "juega", "jugar", "juguemos",
        "nueva", "partida", "el", "la", "los", "las", "una", "un", "por", "favor",
    ]
}
