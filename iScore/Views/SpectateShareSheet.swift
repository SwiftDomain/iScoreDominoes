//
//  SpectateShareSheet.swift
//  iScore
//
//  The scorekeeper's share sheet: a code big enough to read across the table,
//  how many phones are watching, and the way to stop. Sharing starts when the
//  sheet opens and outlives it.
//

import SwiftUI

struct SpectateShareSheet: View {

    let game: Game

    @Environment(SpectateHostLink.self) private var host
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            SheetHeader(title: "Share live score")

            VStack(spacing: 8) {
                Text(host.code?.value ?? "····")
                    .font(DuoFont.score(64))
                    .tracking(12)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityLabel(host.code.map { $0.value.map(String.init).joined(separator: " ") } ?? "")
                Text("Read this code to the table")
                    .font(DuoFont.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .duoCard()

            Label {
                Text(SpectatePolicy.watchingLabel(host.watching))
            } icon: {
                Image(systemName: "eye.fill")
            }
            .font(DuoFont.body)
            .foregroundStyle(host.watching > 0 ? Theme.teamA : Theme.textSecondary)

            Spacer()

            Button("Stop sharing") {
                host.stop()
                dismiss()
            }
            .buttonStyle(.duo(fill: Theme.surface, edge: Theme.divider, foreground: Theme.danger))
        }
        .padding(16)
        .background(Theme.background)
        .task {
            host.start(sharing: game)
        }
    }
}
