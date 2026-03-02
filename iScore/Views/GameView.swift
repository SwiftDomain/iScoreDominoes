import SwiftUI
import SwiftData
import TipKit

struct GameView: View {
    
    @Environment(\.modelContext) var context
    // @FocusState private var fieldIsFocused: Bool
    
    @Binding var path: NavigationPath
    @Bindable var game: Game
    @State private var team: Team?
    @State private var progress1 = 0.0
    @State private var progress2 = 0.0
    @State private var showGameSummary = false
    @State private var gameScoreIndex:GameScoreIndex?
    @State private var showInfoView: Bool = false
    @State private var isNotified: Bool = false
    @State private var showUndoConfirmation = false
    let editScore = editScoreTip()
    
    private let lazyVGridSetup:LazyVGridSetup = LazyVGridSetup()
    
    var body: some View {
        
            ZStack{
                
                VStack {
                    
                    Spacer()
                        .frame(height: 32)
                    
                    // Top current score and progress line
                    HStack{
                        
                        Spacer()
                        
                        VStack{
                            ZStack{
                                
                                Text("\(game.totalScore1)")
                                    .font(.system(size: 45))
                                    .foregroundStyle(Theme.textPrimary)
                                    .bold()
                                
                                //CircularProgressAroundIcon(progress: $progress1)
                                
                            }
                        }
                        .frame(width: 80, height: 80, alignment: .center)
                        
                        
                        Spacer()
                        
                        ZStack{
                            
                            Text("\(game.totalScore2)")
                                .font(.system(size: 45))
                                .foregroundStyle(Theme.textPrimary)
                                .bold()
                            
                            //CircularProgressAroundIcon(progress: $progress2)
                            
                        }
                        .frame(width: 80, height: 80, alignment: .center)
                        
                        Spacer()
                    }
                    //.padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .glassEffect(.clear)

                    Spacer()
                        .frame(height: 16)
                    
                    //Players Names
                    HStack(alignment: .center) {
                        
                        Spacer()
                        
                        BlobShape()
                            .frame(width: 180, height: 80, alignment: .center)
                            .foregroundStyle(.clear)
                            .overlay(
                                
                                TeamView(team: .team1, game: game)
                            )
                        
                        Spacer()
                        BlobShape()
                            .frame(width: 180, height: 80, alignment: .center)
                            .foregroundStyle(.clear)
                            .overlay(
                                
                                TeamView(team: .team2, game: game)
                            )
                        
                        Spacer()
                        
                    }
                    .disabled(game.state != GameState.playing)
                    .glassEffect(.clear)
                    
                    Spacer()
                        .frame(height: 16)
                    
                    
                    //Score for each team
                    ScrollView {

                        HStack(alignment: .center){

                            Spacer()

                            VStack(alignment: .leading){

                                ForEach(game.scoreTeam.indices, id:\.self){index in
                                    if game.scoreTeam[index][0] > 0{

                                        Text("\(game.scoreTeam[index][0] )")
                                            .frame(width: 180, height: 58, alignment: .center)
                                            .minimumScaleFactor(0.75)
                                            .clipShape(.rect(cornerRadius: CornerRadius.thirteen.value))
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
                                .glassEffect(.clear)

                                if game.totalScore1 == 0{
                                    Text("")
                                        .frame(width: 180, height: 58, alignment: .center)
                                        .background(.clear)
                                }
                                Spacer()
                            }

                            Spacer()

                            VStack(alignment: .leading){

                                ForEach(game.scoreTeam.indices, id:\.self){index in
                                    if game.scoreTeam[index][1] > 0{

                                        Text("\(game.scoreTeam[index][1] )")
                                            .frame(width: 180, height: 58, alignment: .center)
                                            .fontWeight(.light)
                                            .minimumScaleFactor(0.75)
                                            .clipShape(.rect(cornerRadius: CornerRadius.thirteen.value))
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
                                .glassEffect(.clear)

                                if game.totalScore2 == 0{
                                    Text("")
                                        .frame(width: 180, height: 60, alignment: .center)
                                        .background(.clear)
                                }
                                Spacer()
                            }
                            .popoverTip(editScore)
                            Spacer()
                        }
                    }
                    .scrollIndicators(.hidden)
                    HStack{
                        
                        Spacer()
                        
                        VStack {

                            Button("Add Score", systemImage: "plus") {
                                self.team = .team1
                            }
                            .buttonStyle(.glass)
                        }
                        
                        Spacer()
                        
                        VStack{
                            Text("Score To Win: \(game.maxScore, format: .number.precision(.fractionLength(0)))")
                                .fontWeight(.thin)
                                .minimumScaleFactor(0.75)
                        }
                        
                        Spacer()
                        
                        VStack {

                            Button("Add Score", systemImage: "plus") {
                                self.team = .team2
                            }
                            .buttonStyle(.glass)
                        }
                        Spacer()
                    }
                    .sheet(item: $team, onDismiss: onDismiss){ team in
                        AddGameScoreView(game: self.game, team: team)
                    }
                    .sheet(item: $gameScoreIndex, onDismiss: onDismiss) {gameScoreIndex in
                        EditScoreView(game: self.game, gameScoreIndex: gameScoreIndex)
                    }
                    .disabled(game.state != GameState.playing)
                }
                .padding(.top, -27)
                .frame(maxWidth: 700)
            }
            .background(Background())
            .sheet(isPresented: $showGameSummary) {
                GameSummaryView(game: game)
            }
            .sheet(isPresented: $showInfoView) {
                CollectionView()
            }
        .onAppear(perform: onAppear)
        .toolbar{
            ToolbarItemGroup(placement: .topBarLeading) {
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    showUndoConfirmation = true
                }
                .disabled(game.scoreTeam.count <= 1 || game.state != .playing)
            }
            ToolbarItemGroup(placement: .topBarTrailing){

                Button(action: {self.showInfoView.toggle()}) {
                    Image(systemName: "info.circle")
                }
                .disabled(game.state != GameState.playing)
            }
        }
        .alert("Undo Last Score", isPresented: $showUndoConfirmation) {
            Button("Undo", role: .destructive) {
                game.scoreTeam.removeLast()
                onAppear()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove the last score entry?")
        }
    }
    
    func onAppear(){
        
        progress1 = (Double(game.totalScore1 ) / game.maxScore > 1 ? 1 : Double(game.totalScore1 ) / game.maxScore)
        progress2 = (Double(game.totalScore2 ) / game.maxScore > 1 ? 1 : Double(game.totalScore2 ) / game.maxScore)
    }
    
    func onDismiss(){
        
        progress1 = (Double(game.totalScore1 ) / game.maxScore > 1 ? 1 : Double(game.totalScore1 ) / game.maxScore)
        progress2 = (Double(game.totalScore2 ) / game.maxScore > 1 ? 1 : Double(game.totalScore2 ) / game.maxScore)
        
        if game.winningTeam != .none && game.state == .playing {
            game.state = .finished
            game.inProcess = false
            showGameSummary = true
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        
        return GameView(path: .constant(NavigationPath()), game: previewer.game)
            .modelContainer(previewer.container)
        //            .task {
        //                try? Tips.resetDatastore()
        //                try? Tips.configure([
        //                    .displayFrequency(.immediate),
        //                    .datastoreLocation(.applicationDefault)])
        //            }
    }
    catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}


enum NotifyAnimationPhase: CaseIterable {
    case initial, lift, shakeLeft, shakeRight
    
    var yOffset: CGFloat {
        switch self {
        case .initial: 0
        case .lift, .shakeLeft, .shakeRight: -15
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .initial: 1
        case .lift, .shakeLeft, .shakeRight: 4.2
        }
    }
    
    var rotationDegress: Double {
        switch self {
        case .initial, .lift: 0
        case .shakeLeft: -30
        case .shakeRight: 30
        }
    }
}

struct CircularProgressAroundIcon: View {
    
    @Binding var progress:Double
    
    var body: some View {
        
        // Circular progress ring around it
        Circle()
            .stroke(
                Color.gray.opacity(0.3),
                lineWidth: 8
            )
            .frame(width: 100, height: 100)
        
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [Theme.accent, Theme.danger]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 8, lineCap: .butt)
            )
            .frame(width: 100, height: 120)
            .rotationEffect(.degrees(-90)) // start from top
            .animation(.bouncy, value: progress)
    }
}

struct TeamView: View {
    
    let team: Team
    let game: Game
    
    
    var body: some View {
        HStack(alignment: .center){
            Image(systemName: game.setSymbol(team: team))
                .resizable()
                .scaledToFit()
                .frame(height: 36)
                .clipShape(.rect(cornerRadius: 8))
                .foregroundStyle((game.winningTeam == team || game.inProcess == true) ? Theme.accent : Theme.danger)
                .phaseAnimator ([ NotifyAnimationPhase.initial,
                                  .lift,
                                  .shakeLeft,
                                  .shakeRight,
                                  .shakeLeft,
                                  .shakeRight
                ], trigger: (game.winningTeam == team)) { content, phase in
                    content
                        .scaleEffect (phase.scale)
                        .rotationEffect(.degrees(phase.rotationDegress), anchor: .top)
                        .offset(y: phase.yOffset)
                }
            animation: { phase in
                switch phase {
                case .initial, .lift: .spring (bounce: 0.5)
                case .shakeLeft, .shakeRight: .easeInOut(duration: 0.15)
                }
            }
            
            VStack(alignment: .leading){
                Text(team == .team1 ? game.team1[0] : game.team2[0])
                    .fontWeight(.light)
                    .minimumScaleFactor(0.75)
                
                Text(team == .team1 ? game.team1[1] : game.team2[1])
                    .fontWeight(.light)
                    .minimumScaleFactor(0.75)
            }
            Spacer()
        }
        .padding()
        .shadow(radius: 19)
    }
}
