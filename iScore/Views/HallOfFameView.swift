//
//  MetaDataView.swift
//  iScore
//
//  Created by BeastMode on 2/9/24.
//
import SwiftUI
import SwiftData
import Charts

struct HallOfFameView: View {
    
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) private var dismiss
    
    @Query( sort:\Player.name, order: .forward ) var players: [Player]
    
    private let lazyVGridSetup:LazyVGridSetup = LazyVGridSetup()
    
    var body: some View {
        
        ZStack{
            
            Background()
            
            ScrollView(showsIndicators: false){
                
                LazyVGrid(columns: lazyVGridSetup.numberColumns, spacing: 30) {
                    
                    Spacer()
                    
                    ZStack {
                        
                        RoundedRectangle(cornerRadius: 10)
                            .frame(width: 250, height: 50)
                            .foregroundStyle(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 11)
                            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 18, height: 18)))
                            .opacity(0.02)
                            .overlay(
                                Text("Hall of Fame")
                                    .foregroundStyle(.accent.opacity(0.7))
                                    .fontWeight(.heavy)
                                    .minimumScaleFactor(0.75)
                                    .font(.largeTitle)
                                    .shadow(color: .black, radius: 55)
                            )
                        
                    }
                                        
                    ForEach(players, id:\.self) { player in
                        
                        VStack{
                            HStack(alignment: .center, spacing: 10){
                                Button(action: {
                                })
                                {

                                        dataBackgroundShape()
                                        .overlay(
                                            
                                            HStack(alignment: .center){
                                                
                                                Text("\(player.name)")
                                                    .fontWeight(.light)
                                                    .minimumScaleFactor(0.75)
                                                    .foregroundStyle(.black)
                                                    .padding(.leading, 20)
                                                    .shadow(color: .white, radius: 25)
                                                    .frame(width: 150, alignment: .leading)
                                                    .padding(.leading, UIDevice.current.userInterfaceIdiom == .pad ? 80 :0)
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .center){
                                                    
                                                    MetaDataCellView(player: player)
                                                    
                                                }
                                                .padding(.trailing, UIDevice.current.userInterfaceIdiom == .pad ? 80 :0)
                                                
                                            }
                                        )
                                        .offset(y:20)
                                        .padding(.horizontal)
                                    
                                    
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct MetaDataCellView:View{
    
    let player: Player
    
    init(player: Player) {
        self.player = player
    }
    
    var body: some View {
        
        VStack(alignment: .leading){
            
            HStack {
                Text("Played: ")
                Spacer()
                Text("\(player.gamesPlayed)")
                    .paddingLeading()
                
            }
            
            HStack {
                Text("Won:")
                Spacer()
                Text("\(player.gamesWon)")
                    .paddingLeading()
                
                
            }
            
            HStack{
                Text("Wins: ")
                Spacer()
                
                Text("\(player.winPercentage, specifier: "%.0f")%")
                    .paddingLeading()
                
            }
            
        }
        .foregroundStyle(.black)
        .frame(width: 150)
    }
}


#Preview {
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    
    let game = Game(gameType:GameType.six, maxScore: 20)
    
    container.mainContext.insert(game)
    
    game.players.append(Player(name: "12345678901"))
    game.team1.append("12345678901")
    
    game.players.append(Player(name: "sjdkvmsjdieo"))
    game.team1.append("12345678901")
    
    game.players.append(Player(name: "ksslsla"))
    game.team2.append("ksslsla")
    
    game.players.append(Player(name: "kklkj4"))
    game.team2.append("ksslsla")
    
    return HallOfFameView()
        .modelContainer(container)
}
