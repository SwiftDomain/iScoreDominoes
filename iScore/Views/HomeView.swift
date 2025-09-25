//
//  ContentView.swift
//  iScore
//
//  Created by Carlos Guerrero on 10/4/23.
//

import SwiftUI
import SwiftData


struct HomeView: View {
    
    @State private var showHallOfFameView: Bool = false
    @State private var showNewGameView: Bool = false
    @State private var showInfoView: Bool = false
    
    @State private var path = NavigationPath()
    
    var body: some View {
        
        NavigationStack(path: $path) {
            
            ZStack{
                
                Background ()
                
                        VStack(alignment: .leading, spacing: 16){
                            
                            NavigationLink(destination: NewGameView(path: $path)){
                                NewGameRow(image: "plus.app", title: "New Game", description: "New Croquetas")
                            }
                            
                            
                            NavigationLink(destination: GamesView(path: $path))
                            {
                                NewGameRow(image: "arcade.stick.console", title: "All Games", description: "Croquetas 305")
                            }
                            
                            Button(action: {self.showHallOfFameView.toggle()})
                            {
                                NewGameRow(image: "trophy", title: "Hall D' Fame", description: "Best Croquetas")
                            }
                            
                            Button(action: {self.showInfoView.toggle()})
                            {
                                NewGameRow(image: "arrowtriangle.right.circle", title: "Tutorials", description: "Learn Croqueta")
                            }
                            
                            Spacer()
                                .frame(height: 100)
                        }
                        .navigationTitle(Text("Dominoes"))
                                        
            }
        }
        .sheet(isPresented: $showHallOfFameView) {
            HallOfFameView()
        }
        .sheet(isPresented: $showNewGameView) {
            NewGameView(path: $path)
        }
        .sheet(isPresented: $showInfoView) {
            CollectionView()
        }
    }
    
}

struct NewGameRow: View{
    
    let image: String
    let title: String
    let description: String
    
    var body: some View {
        
        HStack{
            
            Image(systemName: image)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
                .transition(Twirl())
                .frame(width: 50, height: 50)
                
            
            Spacer()
                .frame(width: 16)
            
            VStack(alignment: .leading){
                Text(title)
                    .fontWeight(.light)
                    .font(.system(size: 30))
                    .foregroundStyle(.primary)
                
                Spacer()
                    .frame(height: 1)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 60)
        .padding(.all, 20.0)
    }
}


#Preview {
    
    HomeView()
        .modelContainer(for: Game.self, inMemory: true)
    
}
