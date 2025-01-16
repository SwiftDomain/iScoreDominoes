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


        game = Game(gameType:GameType.six, maxScore: 200)
        
        container.mainContext.insert(game)
        
        //game.players.append(Player(name: "Test Player"))
        game.team1.append("Beastmode")
        
        //game.players.append(Player(name: "Test Player 2"))
        game.team1.append("Bad Hombre")
        
        //game.players.append(Player(name: "Test Player qerqewr"))
        game.team2.append("Xi Pinging")
        
        //game.players.append(Player(name: "4est Player qerqewr"))
        game.team2.append("Bidenomics")
        
        game.scoreTeam.append([53,0])
       game.scoreTeam.append([0,24])
        game.scoreTeam.append([90,0])
        game.scoreTeam.append([12,0])
        game.scoreTeam.append([01,0])
        game.scoreTeam.append([0,245])
//        game.scoreTeam.append([0,2])
//        game.scoreTeam.append([0,0])
        

    }
}

