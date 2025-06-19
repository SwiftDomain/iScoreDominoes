//
//  Tip.swift
//  iScore
//
//  Created by BeastMode on 6/2/25.
//

import Foundation
import TipKit

struct editScoreTip: Tip{
    
    var title: Text {
        Text("Edit Scores")
    }
    
    var message: Text? {
        Text("You can edit a score by pressing it for two seconds.")
    }
    
    var image: Image?{
        Image(systemName: "pencil.circle")
    }
}
