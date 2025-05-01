//
//  GamesView.swift
//  iScore
//
//  Created by Carlos Guerrero on 10/9/23.
//
import SwiftUI
import SwiftData

struct GamesView: View {
    
    @Environment(\.modelContext) var context
    
    @Query( sort:\Game.timestamp, order: .reverse ) var games: [Game]
    @Query( sort:\Player.name, order: .forward ) var players: [Player]
    
    @Binding var path: NavigationPath
    
    @State private var showSheetView: Bool = false
    @State private var showAlert = false
    @State var searchGame: String = ""
    
    var filteredGames: [Game] {
        guard searchGame.isEmpty == false else { return games }
        
        return games.filter { $0.team1[0].localizedStandardContains(searchGame) || $0.team1[1].localizedStandardContains(searchGame) || $0.team2[0].localizedStandardContains(searchGame) || $0.team2[1].localizedStandardContains(searchGame)}
    }
    
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                context.delete(games[index])
            }
        }
    }
    
    private let lazyVGridSetup:LazyVGridSetup = LazyVGridSetup()
    
    var body: some View {
        ZStack{
            
            Background()
            
            ScrollView(showsIndicators: false){
                
                LazyVGrid(columns: lazyVGridSetup.numberColumns, spacing: 30) {
                    
                    ForEach(filteredGames, id:\.self) { game in
                        
                        VStack{
                            
                            HStack(alignment: .center, spacing: 10){
                                
                                Button(action: {})
                                {
                                    dataBackgroundShape()
                                        .overlay(
                                            
                                            NavigationLink(destination: GameView(path: $path, game: game)) {
                                                
                                                VStack{
                                                    HStack{
                                                        
                                                        GameCellView(game: game, team: .team1)
                                                        
                                                    }
                                                    .padding([.top], 50.0)
                                                    
                                                    
                                                    HStack{
                                                        GameCellView(game: game, team: .team2)
                                                    }
                                                    .padding([.bottom], 50.0)
                                                    
                                                }
                                                .offset(x:30)
                                                .padding(.leading, UIDevice.current.userInterfaceIdiom == .pad ? 80 :0)

                                                Spacer()
                                                
                                                VStack{
                                                    GameMetaDataCellView(game: game)
                                                }
                                                .padding(.trailing, UIDevice.current.userInterfaceIdiom == .pad ? 80 :0)

                                            }
                                        )
                                }
                                .navigationTitle(Text("Games"))
                                .offset(y:10)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchGame)
        .toolbar{
            ToolbarItem(placement: .topBarTrailing){
                Button(action: {}) {
                    
                    NavigationLink(destination: NewGameView(path: $path)) {
                        Text("New Game")
                    }
                    
                }
            }
        }
    }
}



#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    
    for _ in 1...1 {
        let game = Game(gameType:GameType.six, maxScore: 20)
        
        container.mainContext.insert(game)
        
        game.players.append(Player(name: "1"))
        game.team1.append("1")
        
        game.players.append(Player(name: "2"))
        game.team1.append("2")
        
        game.players.append(Player(name: "3"))
        game.team2.append("3")
        
        game.players.append(Player(name: "4"))
        game.team2.append("4")
        
    }
    
    return GamesView(path: .constant(NavigationPath()))
    
        .modelContainer(container)
}
