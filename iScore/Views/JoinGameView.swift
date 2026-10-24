//
//  JoinGameView.swift
//  iScore
//
//  "Watch a game": type the code the scorekeeper read out, then follow the
//  score. One screen, full screen, so the watching phone has nothing else on it.
//

import SwiftUI

struct JoinGameView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var joined: JoinCode?
    @FocusState private var isTyping: Bool

    private var code: JoinCode? { JoinCode(typed: typed) }

    /// Uppercases as it is written. Rewriting `typed` after the fact (in
    /// `onChange`) races the next keystroke and drops letters.
    private var uppercased: Binding<String> {
        Binding(get: { typed }, set: { typed = $0.uppercased() })
    }

    var body: some View {
        if let joined {
            SpectateView(code: joined) { dismiss() }
        } else {
            entry
        }
    }

    private var entry: some View {
        VStack(spacing: 24) {
            SheetHeader(title: "Watch a game")

            VStack(spacing: 8) {
                TextField("K7MQ", text: uppercased)
                    .font(DuoFont.score(48))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isTyping)
                    .submitLabel(.join)
                    .onSubmit(join)
                    .padding(.vertical, 16)
                    .duoCard()
                Text("Enter a code")
                    .font(DuoFont.body)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button("Join", action: join)
                .buttonStyle(.duo(Theme.palette(for: .team1)))
                .disabled(code == nil)
        }
        .padding(16)
        .background(Theme.background)
        .onAppear { isTyping = true }
    }

    private func join() {
        guard let code else { return }
        joined = code
    }
}
