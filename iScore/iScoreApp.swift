//
//  iScoreApp.swift
//  iScore
//
//  Created by Carlos Guerrero on 10/4/23.
//

import SwiftUI
import SwiftData

@main
struct iScoreApp: App {
    
    
    var modelContainer: ModelContainer
    
    init() {
        do {
            
            modelContainer = try ModelContainer(for: Game.self)
        } catch {
            fatalError("Could not initialize ModelContainer")
        }
        
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white]

    }

    var body: some Scene {
        WindowGroup {
         HomeView()
        }
        .modelContainer(modelContainer)
    }
}
