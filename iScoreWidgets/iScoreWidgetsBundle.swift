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
        // The Live Activity lands in a later task; a bundle needs a widget.
        ScoreboardPlaceholderWidget()
    }
}

struct ScoreboardPlaceholderWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScoreboardPlaceholder", provider: PlaceholderProvider()) { _ in
            Text(verbatim: "iScore")
        }
        .supportedFamilies([.systemSmall])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date = Date()
}

struct PlaceholderProvider: TimelineProvider {

    func placeholder(in context: Context) -> PlaceholderEntry { PlaceholderEntry() }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry()], policy: .never))
    }
}
