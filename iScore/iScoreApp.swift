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
            
            modelContainer = try ModelContainer(for: Game.self)
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
