//
//  NewPlayerView.swift
//  iScore
//
//  Created by BeastMode on 2/13/24.
//

import SwiftUI
import SwiftData

struct NewPlayerView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Query( sort:\Player.name, order: .forward ) var players: [Player]
    @Binding var player: String
    @FocusState private var isFocused: Bool
    
    init(player: Binding<String>) {
        
        self._player = player
    }
    
    var SearchPlayers: [Player]{
        
        guard player.isEmpty == false else {
            return players
        }
        
        return players.filter{
            $0.name.lowercased().localizedStandardContains(player.lowercased())
        }
    }
    
    
    var body: some View {
        
        ZStack{
            
            VStack{
                
                HStack(){
                    
                    Image("cigar")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 185, maxHeight: 185)
                        .brightness(0.1)
                        .clipped()
                }
                .padding(.bottom, -8)
                .offset(x: -14)
                
                HStack{
                    
                    BlobShape()
                        .frame(width: 380, height: 55, alignment: .center)
                        .foregroundStyle(.white)
                        .opacity(0.8)
                        .cornerRadius(28)
                        .opacity(0.4)
                        .overlay(
                            
                            TextInputField(text: $player, "Melon Name")
                                .font(.title2)
                                .textContentType(.name)
                                .multilineTextAlignment(.center)
                                .fontWeight(.light)
                                .focused($isFocused)
                            
//                            HStack {
//                                Image(systemName: "person.fill")
//                                    .foregroundColor(.gray)
//                                TextField("Player Name", text: $player)
//                                    .fontWeight(.light)
//                            }
//                            .padding()
                        )
                }
                
                Spacer()
                
                VStack(alignment: .leading){
                    
                    ScrollView(showsIndicators: false){
                        
                        
                        /* List of all players*/
                        ForEach(SearchPlayers, id:\.self) { player in
                            
                            Button(action: {
                                
                                self.player = player.name
                                dismiss()
                                
                            })
                            {
                                Text("\(player.name)")
                                    .font(.title)
                                    .fontWeight(.light)
                                    .foregroundStyle(.primary)
                            }
                            .padding(10)
                           // .buttonStyle(.glass)
                        }
                        
                    }
                    .frame(minWidth: 850)
                }
            }
            .toolbar{
                ToolbarItemGroup(placement: .topBarTrailing){
                    
                    Button(action: {
                        
                        dismiss()
                        
                    })
                    {
                        Text("Add")
                    }
                }
            }
            .onAppear(){
               //isFocused = true
                UITextField.appearance().clearButtonMode = .whileEditing
            }
        }
        .background{
            Background()
        }
    }
}

//Text class
struct TextInputField: View {
    
    @Binding var text: String
    var title: String
    
    init(text: Binding<String>, _ title: String) {
        self._text = text
        self.title = title
    }
    
    private func maxInput() -> String{
        
        if self.text.count > 15{
            self.text = String(text.prefix(15))
        }
        
        return self.text.capitalized
    }
    
    var body: some View {
        
        VStack(alignment: .leading){
            
            Text(title)
                .foregroundStyle(text.isEmpty ? Color(.placeholderText): .accentColor)
                .offset(x:25, y: text.isEmpty ? 22 : 0)
                .scaleEffect(text.isEmpty ? 1 : 0.8, anchor: .leading)
                .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification)) { _ in
                    text = maxInput()
                }
                .frame(alignment: .center)
            
            TextField("", text: $text)
                .foregroundStyle(.black)
                .offset(y:-20)
            
            
        }
    }
}

#Preview {
    
    
    NewPlayerView(player: .constant("Test"))
    
}

