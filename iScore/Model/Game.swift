//
//  Item.swift
//  iScore
//
//  Created by Carlos Guerrero on 10/4/23.
//

import SwiftUI
import SwiftData
 
@Model
class Game: Identifiable {

    @Relationship(deleteRule: .cascade, inverse: \Player.games) var players: [Player]? = []
    
    var gameType: GameType = GameType.six
    var maxScore: Double = 20
    var timestamp: Date = Date()
    var inProcess: Bool = true
    var scoreTeam = [[0,0]]
    var state: GameState = GameState.playing
    var team1: [String] =  [String]()
    var team2: [String] =  [String]()
     
    private(set) var id = UUID()
    
    init(gameType: GameType, maxScore: Double) {

        self.gameType = gameType
        self.maxScore = maxScore

    }
    
    var totalScore1: Int {
        
        var totalScore1 = 0
        
        for score in scoreTeam{
            totalScore1 += score[0]
        }
        
        return totalScore1
    }
    var totalScore2: Int {
        
        var totalScore2 = 0
        
        for score in scoreTeam{
            totalScore2 += score[1]
        }
        
        return totalScore2
    }

    var winningTeam: Team{
        
        if self.totalScore1 >= Int(self.maxScore) {
            
            return .team1
            
        }
        else if self.totalScore2 >= Int(self.maxScore) {
            
            return .team2
        }
        else{
            
            return .none
        }
    }

}

enum GameType: String, Codable, RawRepresentable, CaseIterable, Equatable{
    
    case six
    case nine
    
}

enum GameState: String, Codable, Equatable{
    
    case finished
    case playing
    case cancelled
}

enum Team:Identifiable{
    
    case team1
    case team2
    case none
    
    public var id: Team {return self}
    
    var description:String{
        
        switch self{
            
        case .team1:
            return "Team 1"
        case .team2:
            return "Team 2"
        case .none:
            return "Game in progress"
        }
    }
}
