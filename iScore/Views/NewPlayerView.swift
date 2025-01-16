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
    @Binding var player1: String
    
    init(player1: Binding<String>) {

        self._player1 = player1
    }
    
    
    var body: some View {
        
        ZStack{
            
Background()
            
            VStack{
                
                /* Enter Name */
                HStack(){
        
                    Image("OldGuyCigar")
                        .resizable()
                        .aspectRatio(contentMode: UIDevice.current.userInterfaceIdiom == .pad ? .fit : .fill)

                        .frame(height: 348)
                        .brightness(-0.1)
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
                            TextInputField(text: $player1, "Melon Name")
                                .font(.title2)
                                .textContentType(.name)
                                .multilineTextAlignment(.center)
                                .fontWeight(.light)
                        )
                }
                Spacer()
                VStack(alignment: .leading){
                    ScrollView(showsIndicators: false){
                        /* List of all players*/
                        ForEach(players, id:\.self) { player in
                            
                            
                            Button(action: {
                                
                                player1 = player.name
                                dismiss()
                                
                            })
                            {
                                Text("\(player.name)")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.light)
                                
                            }
                            .padding(.all, 5)
                            
                        }
                    }
                }
                .padding(.top, 25)
                
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
        
        if self.text.count > 11{
            self.text = String(text.prefix(11))
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
    
    
    NewPlayerView(player1: .constant(""))
    
}
