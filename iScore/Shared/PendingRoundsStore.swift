//
//  PendingRoundsStore.swift
//  iScore
//
//  The append-only handoff file in the App Group container: one JSON object
//  per line, in tap order. The widget only ever appends; the app drains.
//
//  Two properties the Lock Screen score depends on:
//
//  * `drain` truncates exactly the bytes it read, so a tap that lands while
//    the app is draining is left in the file rather than thrown away.
//  * A line that will not decode (a kill mid-write, a file from an older
//    build) is skipped, and a drain clears it, so one bad line cannot
//    poison every round that follows.
//

import Foundation

struct PendingRoundsStore {

    let url: URL

    init(url: URL) {
        self.url = url
    }

    /// The real store, or nil when the App Group entitlement is missing.
    static var shared: PendingRoundsStore? {
        AppGroup.pendingRoundsURL.map(PendingRoundsStore.init(url:))
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Writing

    func append(_ round: PendingRound) throws {
        var line = try Self.encoder.encode(round)
        line.append(0x0A)   // newline: the record separator

        let manager = FileManager.default
        if !manager.fileExists(atPath: url.path) {
            try manager.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try line.write(to: url, options: .atomic)
            return
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    // MARK: - Reading

    func load() throws -> [PendingRound] {
        try read().rounds
    }

    /// Returns everything in the file, in tap order, and removes exactly
    /// those bytes — anything appended since the read stays put.
    func drain() throws -> [PendingRound] {
        let (rounds, bytesRead) = try read()
        guard bytesRead > 0 else { return rounds }
        try truncate(toOffset: UInt64(bytesRead))
        return rounds
    }

    /// Drops the first `offset` bytes of the file, keeping the rest.
    func truncate(toOffset offset: UInt64) throws {
        guard let data = try? Data(contentsOf: url) else { return }
        let remainder = offset >= UInt64(data.count) ? Data() : data.dropFirst(Int(offset))
        try Data(remainder).write(to: url, options: .atomic)
    }

    private func read() throws -> (rounds: [PendingRound], bytesRead: Int) {
        guard let data = try? Data(contentsOf: url) else { return ([], 0) }

        // A line that will not decode is skipped — including a final line
        // with no newline, which is a write cut short. The byte count still
        // covers it, so the next drain clears the poison.
        let rounds = data
            .split(separator: 0x0A, omittingEmptySubsequences: true)
            .compactMap { try? Self.decoder.decode(PendingRound.self, from: Data($0)) }
        return (rounds, data.count)
    }
}
