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
    static func match(_ transcript: String, presets: [PresetSetup]) -> PresetSetup? {
        let said = fold(transcript).filter { !fillerWords.contains($0) }
        guard !said.isEmpty else { return nil }
        return presets
            .filter { fold($0.name) == said }
            .max { $0.name.count < $1.name.count }
    }

    /// Lowercased, accents stripped, punctuation turned into spaces, split into words.
    static func fold(_ text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
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
