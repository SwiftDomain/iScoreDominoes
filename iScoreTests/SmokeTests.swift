import Testing
@testable import iScore

@Test func appModuleLoads() {
    #expect(GameType.allCases.count == 2)
}

/// Dismissed tips stay dismissed; only Debug `-demoData` runs start fresh.
@Test func tipsResetOnlyForDemoDataRuns() {
    #expect(iScoreApp.resetsTips(launchArguments: ["iScore", DemoData.launchArgument]))
    #expect(!iScoreApp.resetsTips(launchArguments: ["iScore"]))
}
