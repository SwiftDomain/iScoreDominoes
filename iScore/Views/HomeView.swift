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
            
            ZStack(alignment: .center){
                     
                Background ()
                
                VStack(alignment: .leading, spacing: 16){
                    
                        NavigationLink(destination: NewGameView(path: $path)){
                            
                            HStack{
                                Image(systemName: "plus.app")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.accent)
                                    .transition(Twirl())
                                    .frame(width: 60, height: 60)
                                
                                Spacer()
                                    .frame(width: 16)
                                
                                VStack(alignment: .leading){
                                    Text("New Game")
                                        .fontWeight(.light)
                                        .font(.system(size: 30))
                                    
                                    Spacer()
                                        .frame(height: 1)
                                    
                                    Text("New Croquetas")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: 60)
                            .padding(.all, 30.0)
                            
                        }
                        
                        
                        NavigationLink(destination: GamesView(path: $path))
                        {
                            
                            HStack{
                                Image(systemName: "arcade.stick.console")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.accent)
                                    .transition(Twirl())
                                    .frame(width: 60, height: 60)

                                Spacer()
                                    .frame(width: 16)
                                
                                VStack(alignment: .leading){
                                    Text("All Games")
                                        .fontWeight(.light)
                                        .font(.system(size: 30))
                                    
                                    
                                    Spacer()
                                        .frame(height: 1)
                                    
                                    Text("Croquetas 305")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: 60)
                            .padding(.all, 30.0)
                        }

                        
                        Button(action: {self.showHallOfFameView.toggle()})
                        {
                            HStack{
                                Image(systemName: "trophy")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.accent)
                                    .transition(Twirl())
                                    .frame(width: 60, height: 60)

                                Spacer()
                                    .frame(width: 16)
                                
                                VStack(alignment: .leading){
                                    Text("Hall D' Fame")
                                        .fontWeight(.light)
                                        .font(.system(size: 30))
                                    
                                    Spacer()
                                        .frame(height: 1)
                                    
                                    Text("Best Croquetas")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: 60)
                            .padding(.all, 30.0)
                        }

                        Button(action: {self.showInfoView.toggle()})
                        {
                            HStack{
                                Image(systemName: "arrowtriangle.right.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.accent)
                                    .transition(Twirl())
                                    .frame(width: 60, height: 60)

                                VStack(alignment: .leading){
                                    Text("Tutorials")
                                        .fontWeight(.light)
                                        .font(.system(size: 30))
                                    
                                    
                                    Spacer()
                                        .frame(height: 1)
                                    
                                    Text("Learn Croqueta")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: 60)
                            .padding(.all, 30.0)
                        }
                    }
                    .navigationTitle(Text("Dominoes"))
                    //.offset(y:-60)
                

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


#Preview {
    HomeView()
        .modelContainer(for: Game.self, inMemory: true)
}
