import SwiftUI
import SwiftData

struct GameView: View {
    
    @Environment(\.modelContext) var context
    @FocusState private var fieldIsFocused: Bool
    
    @Binding var path: NavigationPath
    @Bindable var game: Game
    @State private var team: Team?
    @State private var progress1 = 0.0
    @State private var progress2 = 0.0
    @State private var showAlert = false
    @State private var winningMessage: String = ""
    @State private var gameScoreIndex:GameScoreIndex?
    @State private var showInfoView: Bool = false

    
    private let lazyVGridSetup:LazyVGridSetup = LazyVGridSetup()
    
    var body: some View {
        
        NavigationView {
            
            ZStack{
                
                Background()
                
                VStack {
                    // Top current score and progress line
                    HStack{
                        Spacer()
                        ZStack{
                            //BlobShape()
                            Circle()
                                .frame(width: 180, height: 58, alignment: .center)
                                .foregroundStyle(.linearGradient(colors: [.orange, progress1 >= 0.80 ? .red : Color(.lightBlack)], startPoint: .bottomLeading, endPoint: .topTrailing))
                                .overlay(
                                    
                                    VStack{
                                        
                                        Spacer()
                                        
                                        ProgressView(value: progress1)
                                            .progressViewStyle(.automatic)
                                            .tint(progress1 >= 0.80 ? .red : .accentColor)
                                            .offset(y: 10)
                                        
                                    }
                                )
                            Text("\(game.totalScore1)")
                                .font(.title)
                                .foregroundStyle(.accent)
                                .bold()
                        }
                        Spacer()
                        ZStack{
                            Circle()
                                .frame(width: 180, height: 58, alignment: .center)
                                .foregroundStyle(.linearGradient(colors: [.orange, progress2 >= 0.80 ? .red : Color(.lightBlack)], startPoint: .bottomLeading, endPoint: .topTrailing))
                                .overlay(
                                    
                                    VStack{
                                        
                                        Spacer()
                                        
                                        ProgressView(value: progress2)
                                            .progressViewStyle(.automatic)
                                            .tint(progress2 >= 0.80 ? .red : .accentColor)
                                            .offset(y: 10)
                                        
                                    }
                                )
                            Text("\(game.totalScore2)")
                                .font(.title)
                                .foregroundStyle(.accent)
                                .bold()
                        }
                        Spacer()
                    }
                    .padding(.bottom, 16)
                    
                    //Players Names
                    HStack(alignment: .center) {
                        Spacer()
                        BlobShape()
                            .frame(width: 180, height: 58, alignment: .center)
                            .foregroundStyle(.clear)
                            .overlay(
                                HStack(alignment: .center){
                                    Image(systemName: game.setSystemName(team: .team1))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 48)
                                        .cornerRadius(8)
                                        .foregroundStyle(game.winningTeam == .team1 ? .green : .accentColor)
                                        .symbolEffect(.pulse)
                                    
                                    VStack(alignment: .leading){
                                        Text(game.team1[0])
                                            .fontWeight(.light)
                                            .minimumScaleFactor(0.75)
                                        
                                        Text(game.team1[1])
                                            .fontWeight(.light)
                                            .minimumScaleFactor(0.75)
                                    }
                                    Spacer()
                                }
                            )
                        Spacer()
                        BlobShape()
                            .frame(width: 180, height: 58, alignment: .leading)
                            .foregroundStyle(.clear)
                            .overlay(
                                
                                HStack(alignment: .center){
                                    
                                    Image(systemName: game.setSystemName(team: .team2))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 48)
                                        .cornerRadius(8)
                                        .foregroundStyle(game.winningTeam == .team2 ? .green : .accentColor)
                                        .symbolEffect(.pulse)
                                    
                                    VStack(alignment: .leading){
                                        Text(game.team2[0])
                                            .fontWeight(.light)
                                            .minimumScaleFactor(0.75)
                                        
                                        Spacer()
                                            .frame(height: 1)
                                        
                                        Text(game.team2[1])
                                            .fontWeight(.light)
                                            .minimumScaleFactor(0.75)
                                    }
                                    Spacer()
                                })
                            .backgroundStyle(.white)
                        
                        Spacer()
                    }
                    .disabled(game.state != GameState.playing)
                    Spacer()
                        .frame(height: 16)
                    
                    //Score for each team
                    ScrollView(showsIndicators: false){
                        
                        HStack(alignment: .center){
                            
                            Spacer()
                            
                            VStack(alignment: .leading){
                                
                                ForEach(game.scoreTeam.indices, id:\.self){index in
                                    if game.scoreTeam[index][0] > 0{
                                        
                                        Text("\(game.scoreTeam[index][0] )")
                                            .frame(width: 180, height: 58, alignment: .center)
                                            .background(Color.gray.opacity(0.1))
                                            .fontWeight(.light)
                                            .minimumScaleFactor(0.75)
                                            .cornerRadius(CornerRadius.thirteen.value)
                                            .onLongPressGesture(minimumDuration: 1){
                                                
                                                if game.inProcess {
                                                    
                                                    gameScoreIndex = GameScoreIndex()
                                                    
                                                    self.gameScoreIndex!.index = index
                                                    self.gameScoreIndex!.team = .team1
                                                    self.gameScoreIndex!.value = game.scoreTeam[index][0]
                                                    
                                                }
                                                
                                            }
                                    }
                                }
                                if game.totalScore1 == 0{
                                    Text("")
                                        .frame(width: 180, height: 58, alignment: .center)
                                        .background(Color.accentColor.opacity(0))
                                }
                                Spacer()
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading){
                                
                                ForEach(game.scoreTeam.indices, id:\.self){index in
                                    if game.scoreTeam[index][1] > 0{
                                        
                                        Text("\(game.scoreTeam[index][1] )")
                                            .frame(width: 180, height: 58, alignment: .center)
                                            .background(Color.gray.opacity(0.1))
                                            .fontWeight(.light)
                                            .minimumScaleFactor(0.75)
                                            .cornerRadius(CornerRadius.thirteen.value)
                                            .onLongPressGesture(minimumDuration: 1){
                                                
                                                if game.inProcess {
                                                    
                                                    gameScoreIndex = GameScoreIndex()
                                                    
                                                    self.gameScoreIndex!.index = index
                                                    self.gameScoreIndex!.team = .team2
                                                    self.gameScoreIndex!.value = game.scoreTeam[index][1]
                                                }
                                                
                                            }
                                    }
                                }
                                if game.totalScore2 == 0{
                                    Text("")
                                        .frame(width: 180, height: 60, alignment: .center)
                                        .background(Color.accentColor.opacity(0))
                                }
                                Spacer()
                            }
                            
                            Spacer()
                        }
                    }
                    
                    //VStack{
                    HStack{
                        Spacer()
                        VStack {
                            
                            Button(action: {
                                self.team = .team1
                            }
                            ){
                                Image(systemName: "plus.square.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 40)
                                    .cornerRadius(CornerRadius.thirteen.value)
                                    .foregroundStyle(.accent)
                                    .shadow(color: .black, radius: 4)
                                    .brightness(-0.1)
                                
                            }
                        }
                        // .padding(.leading, 75)
                        
                        Spacer()
                        
                        VStack{
                            Text("Score To Win: \(String(format: "%.0f", game.maxScore))")
                                .fontWeight(.light)
                                .minimumScaleFactor(0.75)
                        }
                        
                        Spacer()
                        
                        VStack {
                            
                            Button(action: {
                                self.team = .team2
                            }){
                                Image(systemName: "plus.square.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 40)
                                    .cornerRadius(CornerRadius.thirteen.value)
                                    .foregroundStyle(.accent)
                                    .shadow(color: .black, radius: 4)
                                    .brightness(-0.1)
                            }
                        }
                        Spacer()
                    }
                    .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("\(game.winningTeam.description) won"),
                            message: Text(winningMessage)
                        )
                    }
                    .sheet(item: $team, onDismiss: onDismiss){ team in
                        AddGameScoreView(game: self.game, team: team)
                    }
                    .sheet(item: $gameScoreIndex, onDismiss: onDismiss) {gameScoreIndex in
                        EditScoreView(game: self.game, gameScoreIndex: gameScoreIndex)
                    }
                    .disabled(game.state != GameState.playing)
                }
                // }
                .padding(.top, -27)
            }
            .sheet(isPresented: $showInfoView) {
                CollectionView()
            }
        }
        .onAppear(perform: onAppear)
        .navigationViewStyle(.stack)
        .toolbar{
            ToolbarItemGroup(placement: .topBarTrailing){
                
                Button(action: {self.showInfoView.toggle()}) {
                    Image(systemName: "info.circle")
                }
                .disabled(game.state != GameState.playing)
            }
        }
    }
    
    func onAppear(){
        
        progress1 = (Double(game.totalScore1 ) / game.maxScore > 1 ? 1 : Double(game.totalScore1 ) / game.maxScore)
        progress2 = (Double(game.totalScore2 ) / game.maxScore > 1 ? 1 : Double(game.totalScore2 ) / game.maxScore)
    }
    
    func onDismiss(){
        
        progress1 = (Double(game.totalScore1 ) / game.maxScore > 1 ? 1 : Double(game.totalScore1 ) / game.maxScore)
        progress2 = (Double(game.totalScore2 ) / game.maxScore > 1 ? 1 : Double(game.totalScore2 ) / game.maxScore)
        
        showAlert = (game.winningTeam != .none && game.state == GameState.playing)
        
        if showAlert {
            
            switch game.winningTeam {
            case .team1:
                winningMessage = "\(game.team2[0]) AND \(game.team2[1]) are bad!"
            case .team2:
                winningMessage = "\(game.team1[0]) AND \(game.team1[1]) are bad!"
            case .none:
                winningMessage = ""
            }
            
            game.state = GameState.finished
            game.inProcess = false
        }
        
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        
        return GameView(path: .constant(NavigationPath()), game: previewer.game)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}

