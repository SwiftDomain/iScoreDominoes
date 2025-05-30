import SwiftUI
import SwiftData

struct NewGameView: View {
    
    enum ActiveSheetPlayer: Identifiable {
        case player1, player2, player3, player4
        
        var id: String {
            
            switch self {
            case .player1: return "player1"
            case .player2: return "player2"
            case .player3: return "player3"
            case .player4: return "player4"
            }
        }
    }
    
    @Environment(\.modelContext) var context
    
    @Query( sort:\Player.name, order: .reverse ) var players: [Player]
    @Query( sort:\Game.timestamp, order: .reverse ) var games: [Game]
    
    @Binding var path: NavigationPath
    
    @State private var player1: String = ""
    @State private var player2: String = ""
    @State private var player3: String = ""
    @State private var player4: String = ""
    @State private var gameType: GameType = .nine
    @State private var maxScore: Double = 20
    @State private var timestamp: Date = Date()    
    @State private var game:Game = Game(gameType: .nine, maxScore: 20.00)
    @State private var isShowingObject: Bool = false // State to control navigation
    @State private var activeSheet: ActiveSheetPlayer?
    
    
    
    
    private func addGame(){
        
        game = Game(gameType: gameType, maxScore: maxScore)
        context.insert(game)
        
        addPlayer(game: game, playerName_: player1)
        addPlayer(game: game, playerName_: player2)
        addPlayer(game: game, playerName_: player3)
        addPlayer(game: game, playerName_: player4)
        
        game.team1.append(player1)
        game.team1.append(player2)
        game.team2.append(player3)
        game.team2.append(player4)
        
        isShowingObject.toggle()
        
    }
    
    private func addPlayer(game: Game, playerName_: String){
        
        /* If the player exists on Player add it to game.players, if not create a new one */
        if players.firstIndex(where: {$0.name == playerName_}) != nil {
            game.players.append(players[players.firstIndex(where: {$0.name == playerName_})!])
        }
        else{
            game.players.append(Player(name: playerName_))
        }
        
    }
    
    private func validatePlayers() -> Bool {
        
        //Validate you don't have same playerName on more than one player
        return !(
            player1.lowercased() == player2.lowercased()
            || player1.lowercased() == player3.lowercased()
            || player1.lowercased() == player4.lowercased()
            || player2.lowercased() == player3.lowercased()
            || player2.lowercased() == player4.lowercased()
            || player3.lowercased() == player4.lowercased()
            || player1 == ""
            || player2 == ""
            || player3 == ""
            || player4 == ""
        )
        
    }
    
    var body: some View {
        
        ZStack{
            
            Background()
            
            //The Complete Form
            Form{
                
                //Team 1 section
                Section{
                    
                    VStack{
                        
                        //Player 1
                        Button {
                            activeSheet = .player1
                        } label: {
                            AddPlayerView(player: player1)
                        }
                        
                        //Player2
                        Button {
                            activeSheet = .player2
                        } label: {
                            AddPlayerView(player: player2)
                        }
                        
                    }
                    .listRowBackground(buttonView())
                    .buttonStyle(BorderlessButtonStyle())
                    
                }
                header:{
                    Text("Team 1")
                        .font(.system(size: 16, weight: .light, design: .rounded))
                }
                
                //Team 2 section
                Section{
                    VStack{
                    
                        //Player 3
                        Button {
                            activeSheet = .player3
                        } label: {
                            AddPlayerView(player: player3)
                        }
                        
                        //Player 4
                        Button {
                            activeSheet = .player4
                        } label: {
                            AddPlayerView(player: player4)
                        }
                        
                    }
                    .listRowBackground(buttonView())
                    .buttonStyle(BorderlessButtonStyle())
                    
                }
                header:{
                    Text("Team 2")
                        .font(.system(size: 16, weight: .light, design: .rounded))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top,10)
                
                //Setup section
                Section {
                    
                    VStack{
                        Picker("GameType", selection: $gameType){
                            ForEach(GameType.allCases, id:\.self) { item in
                                Text("\(item.rawValue)")
                            }
                        }
                        .padding(.top, 10.0)
                        .pickerStyle(.automatic)
                        .onChange(of:gameType, initial: true){oldvalue, newValue in
                            
                            switch newValue{
                            case GameType.six:
                                maxScore = 20
                            case GameType.nine:
                                maxScore = 100
                                
                            }
                        }
                        
                        VStack{
                            Slider(value: $maxScore, in:(gameType==GameType.nine ? 0...200:0...100), step: 10)
                            
                                .padding(.vertical, 10.0)
                            
                            Text("Score To Win: \(String(format: "%.0f", maxScore))")
                                .font(.title2)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .padding(.vertical, 10.0)
                                .frame(height: nil)
                                .fontWeight(.medium)
                        }
                    }
                    .listRowBackground(buttonView())
                    
                }
                
                header:{
                    Text("Setup")
                        .font(.system(size: 16, weight: .light, design: .default))
                }
            }
            .padding([.leading, .trailing], UIDevice.current.userInterfaceIdiom == .pad ? 80 : 0)
            .padding(.top, 10)
            .scrollContentBackground(.hidden)
            .navigationBarTitle(Text("New Game"))
            .navigationBarTitleDisplayMode(.automatic)
            .toolbar{
                ToolbarItemGroup(placement: .topBarTrailing){
                    
                    Button("Save",action: addGame)
                        .disabled(!validatePlayers())
                        .navigationDestination(isPresented: $isShowingObject){
                            GameView(path: $path, game: game)
                        }
                }
            }
        }
        .sheet(item: $activeSheet) { item in
            
            switch item {
            case .player1:
                NewPlayerView(player: $player1)
            case .player2:
                NewPlayerView(player: $player2)
            case .player3:
                NewPlayerView(player: $player3)
            case .player4:
                NewPlayerView(player: $player4)
            }
        }
    }
}
    
    struct buttonView: View {
        
        var body: some View {
            
            LinearGradient(gradient: Gradient(colors: [.blue, Color("lightBlue")]), startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .opacity(1)
            
            
        }
    }
    
    extension String: @retroactive Identifiable {
        public typealias ID = Int
        public var id: Int {
            return hash
        }
    }
    
    
    struct NewGameView_Previews: PreviewProvider {
        
        static var previews: some View {
            
            NewGameView(path: .constant(NavigationPath()))
                .modelContainer(for: Game.self, inMemory: true)
            
        }
    }
    
    struct AddPlayerView: View {
        
        var player: String
        
        var body: some View {
            ZStack {
                HStack {
                    
                    Image(systemName: player != "" ? "person.badge.minus" : "person.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .padding(.trailing)
                    Text(player)
                        .font(.title)
                        .fontWeight(.light)
                    
                    Spacer()
                }
                .foregroundStyle(player != "" ? Color.accentColor : Color.black)
            }
            .frame(height: 30)
        }
    }
