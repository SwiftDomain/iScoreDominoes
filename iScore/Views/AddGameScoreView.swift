//
//  AddGameScoreView.swift
//  iScore
//
//  Created by BeastMode on 2/2/24.
//

import SwiftUI
import SwiftData


struct AddGameScoreView: View {
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    
    @State private var game: Game
    @State private var score = ""
    @FocusState private var fieldIsFocused: Bool
    @State private var team: Team
    
    init(game: Game, team: Team) {
        
        _game =  State(initialValue: game)
        _team = State(initialValue: team)
        fieldIsFocused = true
    }
    
    var body: some View {
        
        ZStack{
            
            Background()
            
            VStack(alignment: .center){
                
                VStack{
        
                    Image("\(team == .team1 ? "2" : "3")")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .brightness(-0.1)
                        .mask{
                            Text("\(team == .team1 ? "Team 1" : "Team 2")")
                                .font(.system(size:30))
                                .fontWeight(.light)
                            Circle().frame(width: 350, height: 85)
                                .shadow(radius:  112)
                        }
                }
                
                
                HStack{
                    BlobShape()
                        .frame(width: 380, height: 55, alignment: .center)
                        .foregroundStyle(.white)
                        .cornerRadius(28)
                        .opacity(0.4)
                        .overlay(
                            TextField("Add Score", text: $score, axis: .vertical)
                                .font(.title2)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .focused($fieldIsFocused, equals: true)
                                .fontWeight(.light)
                                .task {
                                    self.fieldIsFocused = true
                                }
                        )
                }
                
                Button(action: {
                    
                    guard let tempScore = Int(score) as Int? else { return}
                    
                    if team == .team1 {
                        game.scoreTeam.append([tempScore,0])
                    }
                    else {
                        game.scoreTeam.append([0,tempScore])
                    }
                    
                    dismiss()
                    
                })
                {
                    
                    HStack{
                        Image(systemName: "plus.circle")
                            .resizable()
                            .scaledToFit()
                            .frame( height: 50)
                            .cornerRadius(8)
                            .foregroundStyle(.accent)
                        
                        
                        Spacer()
                            .frame(width: 16)
                        
                        VStack(alignment: .leading){
                            Text("Add Score")
                                .fontWeight(.light)
                                .minimumScaleFactor(0.75)
                                .font(.system(size: 20))
                            
                            
                            Spacer()
                                .frame(height: 1)
                            
                            Text("New Croqueta")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fontWeight(.light)
                        }

                    }
                }
                .padding(.top, 35)
                Spacer()
            }
            
        }
       
    }
}


struct AddGameScoreView_Previews: PreviewProvider {
    
    
    static var previews: some View {
        let game = Game(gameType:GameType.six, maxScore: 20)
        
        AddGameScoreView(game: game, team: .team1)
        // .previewInterfaceOrientation(.portrait)
    }
}
