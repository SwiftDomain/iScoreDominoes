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
                
                Background()
                
                VStack(alignment: .center){
                    Spacer()
                    NavigationLink(destination: NewGameView(path: $path)){
                        HStack{
                            Image(systemName: "plus.app")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 50)
                            //.cornerRadius(8)
                                .foregroundStyle(.accent)
                            
                            Spacer()
                                .frame(width: 16)
                            
                            VStack(alignment: .leading){
                                Text("New Game")
                                    .fontWeight(.light)
                                    .minimumScaleFactor(0.75)
                                    .font(.system(size: 20))
                                
                                Spacer()
                                    .frame(height: 1)
                                
                                Text("New Croquetas")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        .padding(.all, 30)
                    }
                    NavigationLink(destination: GamesView(path: $path))
                    {
                        
                        HStack{
                            //    Image(systemName: "arrowtriangle.right.circle")
                            Image(systemName: "arcade.stick.console")
                                .resizable()
                                .scaledToFit()
                                .frame( height: 37)
                                .cornerRadius(8)
                                .foregroundStyle(.accent)
                            
                            Spacer()
                                .frame(width: 16)
                            
                            VStack(alignment: .leading){
                                Text("Games")
                                    .fontWeight(.light)
                                    .minimumScaleFactor(0.75)
                                    .font(.system(size: 20))
                                
                                
                                Spacer()
                                    .frame(height: 1)
                                
                                Text("Croquetas 305")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding([ .leading, .trailing], 30.0)
                    
                    Button(action: {self.showHallOfFameView.toggle()})
                    {
                        HStack{
                            Image(systemName: "trophy")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 50)
                                .cornerRadius(8)
                                .foregroundStyle(.accent)
                            
                            Spacer()
                                .frame(width: 16)
                            
                            VStack(alignment: .leading){
                                Text("Hall of Fame")
                                    .fontWeight(.light)
                                    .minimumScaleFactor(0.75)
                                    .font(.system(size: 20))
                                
                                Spacer()
                                    .frame(height: 1)
                                
                                Text("Best Croquetas")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.all, 30)
                    
                    Button(action: {self.showInfoView.toggle()})
                    {
                    HStack{
                        Image(systemName: "arrowtriangle.right.circle")
                            .resizable()
                            .scaledToFit()
                            .frame( height: 50)
                            .cornerRadius(8)
                            .foregroundStyle(.accent)
                        
                        VStack(alignment: .leading){
                            Text("Tutorial")
                                .fontWeight(.light)
                                .minimumScaleFactor(0.75)
                                .font(.system(size: 20))
                            
                            
                            Spacer()
                                .frame(height: 1)
                            
                            Text("Learn Croqueta")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding([ .leading, .trailing], 30.0)
                    
                    Spacer()

                }
                .navigationTitle(Text("Dominoes"))
                .offset(y:-60)
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
}


#Preview {
    HomeView()
        .modelContainer(for: Game.self, inMemory: true)
}
