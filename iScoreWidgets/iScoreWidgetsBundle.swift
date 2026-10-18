//
//  iScoreWidgetsBundle.swift
//  iScoreWidgets
//
//  Hosts the Lock Screen scoreboard Live Activity. This process never opens
//  the SwiftData store — scoring taps append to the App Group's pending
//  rounds file and the app drains them.
//

import SwiftUI
import WidgetKit

@main
struct iScoreWidgetsBundle: WidgetBundle {

    var body: some Widget {
        ScoreboardLiveActivity()
    }
}
