//
//  AppGroupTests.swift
//  iScoreTests
//
//  The App Group is how the widget hands scored rounds to the app. A missing
//  entitlement is a silent, device-only failure, so assert on the files too.
//

import Foundation
import Testing
@testable import iScore

struct AppGroupTests {

    @Test func identifierMatchesTheEntitlements() {
        #expect(AppGroup.identifier == "group.SwiftDomainUI.iScore")
    }

    @Test func pendingRoundsFileSitsInTheContainer() {
        let container = URL(fileURLWithPath: "/tmp/container", isDirectory: true)
        let url = AppGroup.pendingRoundsURL(containerURL: container)
        #expect(url.lastPathComponent == "pending-rounds.jsonl")
        #expect(url.deletingLastPathComponent().lastPathComponent == "container")
    }

    @Test func bothEntitlementsFilesDeclareTheGroup() throws {
        for path in ["iScore/iScore.entitlements", "iScoreWidgets/iScoreWidgets.entitlements"] {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // iScoreTests
                .deletingLastPathComponent()   // repo root
                .appendingPathComponent(path)
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(text.contains("com.apple.security.application-groups"), "\(path)")
            #expect(text.contains(AppGroup.identifier), "\(path)")
        }
    }
}
