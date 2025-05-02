//
//  Player.swift
//  iScore
//
//  Created by BeastMode on 2/9/24.
//

import SwiftUI
import SwiftData

@Model
class Player: Equatable{
    
    var name: String
    var games: [Game] = [Game]()
    
    init(name: String) {
        
        self.name = name
        
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        
        return lhs.name.lowercased() == rhs.name.lowercased()
        
    }
    
    var gamesWon: Int{
        
        var wins: Int = 0
        
        
        for game in games{
            
            if !game.inProcess{
                
                if  game.winningTeam == .team1 && game.team1.contains(self.name){
                    
                    wins += 1
                    
                }
                else  if  game.winningTeam == .team2 && game.team2.contains(self.name){
                    
                    wins += 1
                    
                }
            }
        }
        
        return wins
        
    }
    
    var gamesPlayed: Int{
        
        var played: Int = 0
        
        for game in games{
            
            if !game.inProcess{
                played += 1
            }
        }
        
        return played
    }
    
    var winPercentage: Double{
        
        
        return (gamesPlayed > 0 ? (Double(self.gamesWon)/Double(self.gamesPlayed) * 100.0) : 0)
    }
    
}
