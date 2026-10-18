//
//  AppGroup.swift
//  iScore
//
//  The shared container the app and the widget hand rounds through. The
//  widget never opens the SwiftData store: a Lock Screen tap appends to
//  `pendingRoundsURL` and the app drains it. Keep this file free of anything
//  the widget cannot link.
//

import Foundation

enum AppGroup {

    static let identifier = "group.SwiftDomainUI.iScore"

    /// The group container, or nil when the entitlement is missing (an
    /// unsigned build, or a device whose profile predates the capability).
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Defaults shared with the widget process. Falls back to `.standard`
    /// so a missing entitlement degrades to app-only rather than crashing.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// Rounds tapped on the Lock Screen, one JSON object per line.
    static func pendingRoundsURL(containerURL: URL) -> URL {
        containerURL.appendingPathComponent("pending-rounds.jsonl")
    }

    static var pendingRoundsURL: URL? {
        containerURL.map(pendingRoundsURL(containerURL:))
    }
}
