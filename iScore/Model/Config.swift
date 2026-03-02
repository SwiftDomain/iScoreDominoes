//
//  Config.swift
//  iScore
//
//  Created by BeastMode on 3/6/24.
//

import SwiftUI

/// App background — gradient from deep navy to slate blue.
struct Background: View {

    var body: some View {
        Theme.backgroundGradient
            .ignoresSafeArea()
    }
}

/// Rounded capsule background shape used for data cells.
struct DataBackgroundShape: View {

    var body: some View {
        RoundedRectangle(cornerRadius: 36, style: .circular)
            .frame(minWidth: 380, maxWidth: 1200, minHeight: 125, maxHeight: 150)
            .clipShape(.capsule)
            .foregroundStyle(Theme.surface)
            .opacity(0.5)
    }
}

/// Corner radius constants used throughout the app.
enum CornerRadius: CGFloat, Codable, RawRepresentable, CaseIterable, Equatable {

    case thirteen
    case twentyFour

    var value: CGFloat {
        switch self {
        case .thirteen:
            return 13
        case .twentyFour:
            return 24
        }
    }
}

/// Shape for game cells.
struct BlobShape: Shape {

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.addRect(CGRect(x: 0, y: 0, width: width, height: height))
        return path
    }
}

/// Displays a team's two player names and symbol in a game cell.
struct GameCellView: View {

    let game: Game
    let team: Team
    let winner: Bool

    init(game: Game, team: Team) {
        self.game = game
        self.team = team
        self.winner = (game.winningTeam == team)
    }

    var body: some View {
        ZStack {
            HStack(alignment: .center) {
                Image(systemName: game.setSymbol(team: team))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(winner ? Theme.accent : (game.inProcess ? Theme.textSecondary : Theme.danger))

                Spacer()
                    .frame(width: 16)

                VStack(alignment: .leading) {
                    Text(team == .team1 ? game.team1[0] : game.team2[0])
                        .foregroundStyle(Theme.textPrimary)
                        .frame(height: 1)

                    Text(team == .team1 ? game.team1[1] : game.team2[1])
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(width: 150, alignment: .leading)
            }
            Spacer()
        }
    }
}

/// Displays game metadata: type, score, and date.
struct GameMetaDataCellView: View {

    let game: Game

    var body: some View {
        VStack {
            Text("Double: \(game.gameType.rawValue)")
            Text("\(game.totalScore1) to \(game.totalScore2)")
            Text(game.timestamp.formatted(date: .numeric, time: .omitted))
        }
        .foregroundStyle(Theme.textSecondary)
        .frame(width: 150)
    }
}

/// Helper modifier for player stat labels in Hall of Fame.
extension Text {

    func paddingLeading() -> some View {
        self.frame(width: 60, alignment: .leading)
            .minimumScaleFactor(0.75)
            .foregroundStyle(Theme.textPrimary)
            .padding(.leading, 20)
            .shadow(color: Theme.accent.opacity(0.3), radius: 15)
    }
}

/// Custom transition with rotation and scale.
struct Twirl: Transition {

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : 0.5)
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : 20)
            .rotationEffect(.degrees(phase == .willAppear ? 360 : phase == .didDisappear ? -360 : .zero))
            .brightness(phase == .willAppear ? 1.0 : 0)
    }
}
