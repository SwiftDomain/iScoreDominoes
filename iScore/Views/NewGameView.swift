import SwiftUI
import SwiftData

struct NewGameView: View {
    
    @Environment(\.modelContext) var context
    
    @Query( sort:\Player.name, order: .reverse ) var players: [Player]
    @Query( sort:\Game.timestamp, order: .reverse ) var games: [Game]
    
    @Binding var path: NavigationPath
    
    @State private var player1: String = ""
    @State private var player2: String = ""
    @State private var player3: String = ""
    @State private var player4: String = ""
    @State private var gameType: GameType = GameType.six
    @State private var maxScore: Double = 20
    @State private var timestamp: Date = Date()
    @State private var showNewPlayerView1: Bool = false
    @State private var showNewPlayerView2: Bool = false
    @State private var showNewPlayerView3: Bool = false
    @State private var showNewPlayerView4: Bool = false
    
    @State private var game:Game = Game(gameType: .nine, maxScore: 20.00)
    @State private var isShowingObject: Bool = false // State to control navigation
    
    
    
    func addGame(){
        
        
        
        game = Game(gameType: gameType, maxScore: maxScore)
        
        context.insert(game)
        
        /* Add players and Teams */
        player1 = player1.lowercased()
        player2 = player2.lowercased()
        player3 = player3.lowercased()
        player4 = player4.lowercased()
        
        /* If the player exists on Player add it to game.players, if not create a new one */
        if players.firstIndex(where: {$0.name == player1}) != nil {
            
            game.players.append(players[players.firstIndex(where: {$0.name == player1})!])
            
        }
        else{
            game.players.append(Player(name: player1))
        }
        
        /* If the player exists on Player add it to game.players, if not create a new one */
        if players.firstIndex(where: {$0.name == player2}) != nil {
            
            game.players.append(players[players.firstIndex(where: {$0.name == player2})!])
            
        }
        else{
            game.players.append(Player(name: player2))
        }
        
        /* If the player exists on Player add it to game.players, if not create a new one */
        if players.firstIndex(where: {$0.name == player3}) != nil {
            
            game.players.append(players[players.firstIndex(where: {$0.name == player3})!])
            
        }
        else{
            game.players.append(Player(name: player3))
        }
        
        /* If the player exists on Player add it to game.players, if not create a new one */
        if players.firstIndex(where: {$0.name == player4}) != nil {
            
            game.players.append(players[players.firstIndex(where: {$0.name == player4})!])
            
        }
        else{
            game.players.append(Player(name: player4))
        }
        
        game.team1.append(player1)
        game.team1.append(player2)
        game.team2.append(player3)
        game.team2.append(player4)
        
        isShowingObject.toggle()
    
    }
    
    var body: some View {
        
        ZStack{
            
            Background()
            
            Form{
                
                Section{
                    
                    VStack {
                        Button(action: {showNewPlayerView1.toggle()})
                        {
                            
                            ZStack {
                                buttonView()
                                HStack {
                                    Spacer()
                                    
                                    Text(player1 != "" ? player1 : "Add Player")
                                        .font(.title2)
                                        .fontWeight(.light)

                                    Spacer()
                                }
                            }
                        }
                        .foregroundStyle(player1 != "" ? Color.accentColor : Color.black)
                        .shadow(color: .black, radius: player1 != "" ? 4 : 0)
                        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 15, height: 10)))
                        
                    }
                    
                    
                    
                    VStack {
                        Button(action: {showNewPlayerView2.toggle()})
                        {
                            ZStack {
                                buttonView()
                                HStack {
                                    Spacer()
                                    Text(player2 != "" ? player2 : "Add Player")
                                        .font(.title2)
                                        .fontWeight(.light)

                                    Spacer()
                                }
                            }
                            
                        }
                        .foregroundStyle(player2 != "" ? Color.accentColor : Color.black)
                        .shadow(color: .black, radius: player2 != "" ? 4 : 0)
                        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 15, height: 10)))
                    }
                }
            header:{
                Text("Team 1")
                    .font(.system(size: 16, weight: .light, design: .rounded))
                
                
            }
            .listRowBackground(
         
                Rectangle()
                    .foregroundStyle( .lightBlue)
                    .foregroundStyle(.shadow(.inner(color: .black, radius: 10)))
                    .opacity(0)
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
           .padding(.top,10)
          
           
                
                Section{
                    
                    VStack{
                        
                        Button(action: {showNewPlayerView3.toggle()})
                        {
                            ZStack {
                                buttonView()
                                HStack {
                                    
                                    Spacer()
                                    Text(player3 != "" ? player3 : "Add Player")
                                        .font(.title2)
                                        .fontWeight(.light)

                                    Spacer()
                                }
                            }
                            
                        }
                        .foregroundStyle(player3 != "" ? Color.accentColor : Color.black)
                        .shadow(color: .black, radius: player3 != "" ? 4 : 0)
                        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 15, height: 10)))
                       
                    }
                    
                    VStack{
                        
                        Button(action: {showNewPlayerView4.toggle()})
                        {
                            ZStack{
                                buttonView()
                                HStack {
                                    
                                    Spacer()
                                    Text(player4 != "" ? player4 : "Add Player")
                                        .font(.title2)
                                        .fontWeight(.light)
                                    Spacer()
                                }
                            }
                        }
                        .foregroundStyle(player4 != "" ? Color.accentColor : Color.black)
                        .shadow(color: .black, radius: player4 != "" ? 4 : 0)
                        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 15, height: 10)))
                    }
                    
                    
                }
            header:{
                Text("Team 2")
                    .font(.system(size: 16, weight: .light, design: .rounded))
            }
            .listRowBackground(
                
                Rectangle()
                    .foregroundStyle( .lightBlue)
                    .foregroundStyle(.shadow(.inner(color: .black, radius: 10)))
                    .opacity(0)
                
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top,10)
                
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
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .padding(.vertical, 10.0)
                                .frame(height: nil)
                                .fontWeight(.light)

                        }
                        
                    }
                    
                    .listRowBackground(buttonView())

                }
                
            header:{
                Text("Setup")
                    .font(.system(size: 16, weight: .light, design: .default))
            }
                
                
            }
            .padding([.leading, .trailing], UIDevice.current.userInterfaceIdiom == .pad ? 80 :0)
            .scrollContentBackground(.hidden)
            .navigationBarTitle(Text("New Game"))
            .navigationBarTitleDisplayMode(.automatic)
            .toolbar{
                ToolbarItemGroup(placement: .topBarTrailing){
                    
                    Button("Save",action: addGame)
                        .disabled(player1 == "" || player2 == "" || player3 == "" || player4 == "")
                        .navigationDestination(isPresented: $isShowingObject){
                            GameView(path: $path, game: game)
                        }
                }
            }
        }
        .sheet(isPresented: $showNewPlayerView1){
            NewPlayerView(player1: $player1)
        }
        .sheet(isPresented: $showNewPlayerView2){
            NewPlayerView(player1: $player2)
        }
        .sheet(isPresented: $showNewPlayerView3){
            NewPlayerView(player1: $player3)
        }
        .sheet(isPresented: $showNewPlayerView4){
            NewPlayerView(player1: $player4)
        }
    }
}

struct buttonView: View {
        
    var body: some View {
          
        LinearGradient(gradient: Gradient(colors: [.blue, Color("lightBlue")]), startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .opacity(0.7)
            
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
