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
    
    /// A game that keeps an id from elsewhere — a spectated game saved by a
    /// guest — so the same game arriving again is recognisably the same.
    convenience init(gameType: GameType, maxScore: Double, id: UUID) {
        self.init(gameType: gameType, maxScore: maxScore)
        self.id = id
    }

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

enum GameState: String, Codable, Equatable{

    case finished
    case playing
    case cancelled
}

// `GameType` and `Team` moved to iScore/Shared/GameEnums.swift: the widget
// extension needs them (point grids, team colors) and must not link SwiftData.
