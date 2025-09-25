//
//  EditScore.swift
//  iScore
//
//  Created by BeastMode on 2/8/24.
//

import SwiftUI

struct EditScoreView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    
    @State private var game: Game
    @State private var gameScoreIndex: GameScoreIndex
    @State private var score = ""
    
    @FocusState private var fieldIsFocused: Bool
    
    init(game: Game, gameScoreIndex: GameScoreIndex) {
        
        _game = State(initialValue: game)
        _gameScoreIndex = State(initialValue:gameScoreIndex)
        fieldIsFocused = true
    }
    
    
    var body: some View {
        
        ZStack{
                    
            VStack(alignment: .center){
                
                VStack{
        
                    Image("player")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 125, height: 125, alignment: .center)
                        .mask{
                            Circle()
                                .frame(width: 125, height: 125, alignment: .center)
                        }
                }
                
                HStack{
                    BlobShape()
                        .frame(width: 380, height: 55, alignment: .center)
                        .foregroundStyle(.white)
                        .opacity(0.8)
                        .cornerRadius(27)
                        .opacity(0.4)
                        .overlay(
                            TextField("Old Score: \(game.scoreTeam[gameScoreIndex.index][(gameScoreIndex.team == .team1 ? 0 : 1)])", text: $score, axis: .vertical)
                                .font(.title2)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .focused($fieldIsFocused, equals: true)
                                .fontWeight(.light)
                                .task {
                                    self.fieldIsFocused = true
                                }
                                .onTapGesture {
                                    score = ""
                                }
                        )
                }
                .padding(.bottom, 45)
                Button(action: {
                    
                    
                    guard let tempScore = Int(score) as Int? else { return}
                    
                    game.scoreTeam[gameScoreIndex.index][(gameScoreIndex.team == .team1 ? 0 : 1)] = tempScore
                    
                    dismiss()
                    
                })
                {
                    
                    HStack{
                        Image(systemName: "pencil.circle")
                            .resizable()
                            .scaledToFit()
                            .frame( height: 50)
                            .cornerRadius(8)
                            .foregroundStyle(.accent)
                        
                        Spacer()
                            .frame(width: 16)
                        
                        VStack(alignment: .leading){
                            Text("Edit")
                                .fontWeight(.light)
                                .minimumScaleFactor(0.75)
                                .font(.system(size: 20))
                            
                            Spacer()
                                .frame(height: 1)
                            
                            Text("Croquetas 305")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fontWeight(.light)
                        }
                    }
                }
                
                Spacer()
                
            }
        }
        .background{
            Background()
                .ignoresSafeArea()

        }
    }
}

struct EditScoreView_Previews: PreviewProvider {
    
    
    static var previews: some View {
        let game = Game(gameType:GameType.six, maxScore: 20)
        
        EditScoreView(game: game, gameScoreIndex: GameScoreIndex())
        
    }
}
