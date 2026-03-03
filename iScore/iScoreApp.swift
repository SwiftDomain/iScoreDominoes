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
    
    init() {
        do {
            let schema = Schema([Game.self, Player.self])
            let config = ModelConfiguration(cloudKitDatabase: .automatic)
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not initialize ModelContainer")
        }
    }

    var body: some Scene {
       
        WindowGroup {
         
            HomeView()
                .task {
                    try? Tips.resetDatastore()
                    try? Tips.configure([
//                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)])
                }
            

        }
        .modelContainer(modelContainer)
    }
}
