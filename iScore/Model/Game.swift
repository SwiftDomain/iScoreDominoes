//
//  Item.swift
//  iScore
//
//  Created by Carlos Guerrero on 10/4/23.
//

import SwiftUI
import SwiftData
 
@Model
class Game: ObservableObject, Identifiable {

    @Relationship(deleteRule: .cascade, inverse: \Player.games) var players: [Player] = [Player]()
    
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
    
    func printPlayers() {
        
        for index in players.indices {

            print("\(index) - \(players[index])")
        }
        
    }
    
    /* Get the current System icon based on state */
    func setSymbol(team: Team) -> String{
        
        var symbolName = ""
        
        if self.state == GameState.playing {
            symbolName = "person.2.circle"
        }
        else if self.state == GameState.cancelled{
            symbolName = "figure.walk.motion.trianglebadge.exclamationmark"
        }
        else if winningTeam == (team == .team1 ? .team1 : .team2)
        {
            symbolName = "trophy"
        }
        else{
            symbolName = "xmark.octagon.fill"
        }
        
        return symbolName
        
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

struct LazyVGridSetup{
    
    let colors: [Color] = [.red, .green, .blue, .yellow]
    
    // Flexible, custom amount of columns that fill the remaining space
    let numberColumns = [
        GridItem(.flexible())
        //, GridItem(.flexible())
    ]
    
    // Adaptive, make sure it's the size of your smallest element.
    let adaptiveColumns = [
        GridItem(.adaptive(minimum: 200))
    ]
    
    // Fixed, creates columns with fixed dimensions
    let fixedColumns = [
        GridItem(.flexible(minimum: 200, maximum: 2500))
        //        ,GridItem(.fixed(200))
    ]
}

class GameScoreIndex:Identifiable{
   
    public var id: GameScoreIndex{return self}
    
    var index: Int = 0
    var team: Team = .none
     var value: Int = 0
    
}
