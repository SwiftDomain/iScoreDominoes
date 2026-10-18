//
//  AppliedRoundsLedger.swift
//  iScore
//
//  A short memory of the pending rounds already written to SwiftData.
//  Draining saves first and truncates second, so a kill in between would
//  otherwise replay those taps and double the score. The ledger is a FIFO
//  of the last `limit` ids in the App Group defaults — small, shared, and
//  no schema change.
//

import Foundation

struct AppliedRoundsLedger {

    static let defaultKey = "appliedPendingRoundIDs"

    private let defaults: UserDefaults
    private let key: String
    private let limit: Int

    init(defaults: UserDefaults, key: String = defaultKey, limit: Int = 200) {
        self.defaults = defaults
        self.key = key
        self.limit = limit
    }

    private var ids: [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func contains(_ id: UUID) -> Bool {
        ids.contains(id.uuidString)
    }

    /// Keeps the most recent `limit` ids; older ones are forgotten, by which
    /// point their file lines are long gone.
    mutating func record(_ newIDs: [UUID]) {
        guard !newIDs.isEmpty else { return }
        let combined = ids + newIDs.map(\.uuidString)
        defaults.set(Array(combined.suffix(limit)), forKey: key)
    }
}
