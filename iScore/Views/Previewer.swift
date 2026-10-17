//
//  Previewer.swift
//  FaceFacts
//
//  Created by Paul Hudson on 22/12/2023.
//

import Foundation
import SwiftData

@MainActor
struct Previewer {

    let container: ModelContainer
    let game: Game

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Game.self, configurations: config)

        // Same sample games the app shows with the `-demoData` launch argument.
        game = DemoData.seed(into: container.mainContext)
    }
}
