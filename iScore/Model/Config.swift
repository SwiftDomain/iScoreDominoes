//
//  Config.swift
//  iScore
//
//  Created by BeastMode on 3/6/24.
//

import SwiftUI

struct Background: View {
    
    var body: some View {
        
//        LinearGradient(gradient: Gradient(colors: [.darkBlue, Color("lightBlue")])
//                       , startPoint: .center
//                       , endPoint: .bottomTrailing)
//        
//        .ignoresSafeArea()
//        //.opacity(0.7)
        
        Image("background")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea(edges: [.top, .bottom])
        
    }
    
}

struct dataBackgroundShape: View{
    
    var body: some View {
        
       // BlobShape()
        RoundedRectangle(cornerRadius: 36, style: .circular)
            //.opacity(0.9)
            .frame(minWidth: 380, maxWidth: 1200, minHeight: 125, maxHeight: 150)
            .clipShape(.capsule)
            .foregroundStyle(.babyBlue)
            .opacity(0.3)
    }
    
}

enum CornerRadius: CGFloat, Codable, RawRepresentable, CaseIterable, Equatable{
    
    case thirteen
    case twentyFour
    
    var value:CGFloat{
        
        switch self{
            
        case .thirteen:
            return 13
        case .twentyFour:
            return 24
            
        }
        
    }
    
}

//Shape for the game's cell
struct BlobShape: Shape {
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.addRect(CGRect(x: 0, y: 0, width: width, height: height))
        
        return path
    }
}

//GameCellView create the cell for the game.  Two teams, 4 players
struct GameCellView: View {
    
    let game: Game
    let team: Team
    let winner: Bool
    
    init( game: Game, team: Team) {
        
        self.game = game
        self.team = team
        
        winner = ( game.winningTeam == team)
    }
    
    var body: some View {
        
        ZStack {
            
            HStack(alignment: .center){
                
                Image(systemName: game.setSymbol(team: team))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(winner ? Color.accentColor : (game.inProcess ? Color.accentColor : .secondary))
                
                
                Spacer()
                    .frame(width: 16)
                
                VStack(alignment: .leading){
                    
                    Text("\(team == .team1 ? game.team1[0] : game.team2[0])")
                        .fontWeight(.light)
                        .foregroundStyle(.black)
                        .frame(height: 1)
                    
                    
                    Text("\(team == .team1 ? game.team1[1] : game.team2[1])")
                        .fontWeight(.light)
                        .foregroundStyle(.black)
                    
                }
                .frame(width: 150, alignment: .leading)
            }
            Spacer()
        }
    }
}

struct GameMetaDataCellView:View{
    
    let game: Game
    
    init(game: Game) {
        self.game = game
    }
    
    var body: some View {
        VStack{
            
            Text("Double: \(game.gameType.rawValue)")
                .fontWeight(.light)
            Text("\(game.totalScore1) to \(game.totalScore2)")
                .fontWeight(.light)
            Text("\(game.timestamp.formatted(date: .numeric, time: .omitted))")
                .fontWeight(.light)
            
            
        }
        .foregroundStyle(.black)
        .frame(width: 150)
    }
}

extension Text{
    
    func paddingLeading() -> some View {
        
        self.frame(width: 60, alignment: .leading)
            .fontWeight(.light)
            .minimumScaleFactor(0.75)
            .foregroundStyle(.black)
            .padding(.leading, 20)
            .shadow(color: .white, radius: 25)
    }
    
}

struct Twirl: Transition {
    
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : 0.5)
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : 20)
            .rotationEffect(.degrees (phase == .willAppear ? 360 : phase == .didDisappear ? -360 : .zero))
            .brightness (phase == .willAppear ? 1.0 : 0)
    }
}
