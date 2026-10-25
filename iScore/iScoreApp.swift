//
//  iScoreApp.swift
//  iScore
//
//  Created by Carlos Guerrero on 10/4/23.
//

import SwiftUI
import SwiftData
import TipKit

@main
struct iScoreApp: App {
    
    
    var modelContainer: ModelContainer

    /// Carries a Lock Screen "Other…" tap to the game's own screen.
    @State private var linkRouter = ScoreLinkRouter()

    /// Tips remember being dismissed. Only Debug `-demoData` runs start with
    /// fresh tips, so simulator checks always see them.
    static func resetsTips(launchArguments: [String]) -> Bool {
        #if DEBUG
        return launchArguments.contains(DemoData.launchArgument)
        #else
        return false
        #endif
    }

    init() {
        // iOS Settings can change the app's language behind the in-app picker,
        // so the language the bundle chose is recorded as the truth each launch.
        LanguageSettings.adopt(.shown(preferredLocalizations: Bundle.main.preferredLocalizations),
                               group: AppGroup.defaults)
        do {
            let schema = Schema([Game.self, Player.self])
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains(DemoData.launchArgument) {
                let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                modelContainer = try ModelContainer(for: schema, configurations: config)
                DemoData.seed(into: modelContainer.mainContext)
                return
            }
            #endif
            let config = ModelConfiguration(cloudKitDatabase: .automatic)
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not initialize ModelContainer")
        }
    }

    var body: some Scene {

        WindowGroup {

            HomeView()
                // Duo theme is a fixed light palette with rounded type; keep
                // system chrome (nav bars, sheets) light regardless of device mode.
                .environment(linkRouter)
                .preferredColorScheme(.light)
                .fontDesign(.rounded)
                .task {
                    if Self.resetsTips(launchArguments: ProcessInfo.processInfo.arguments) {
                        try? Tips.resetDatastore()
                    }
                    try? Tips.configure([
//                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)])
                }

        }
        .modelContainer(modelContainer)
    }
}
