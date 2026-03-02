//
//  SettingsView.swift
//  iScore
//
//  Settings screen for game defaults, player management, and app info.
//

import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Player.name) private var players: [Player]

    @AppStorage("defaultGameType") private var defaultGameType = "nine"
    @AppStorage("defaultMaxScore") private var defaultMaxScore = 100.0

    @State private var showDeleteConfirmation = false
    @State private var playerToDelete: Player?

    var body: some View {
        NavigationStack {
            ZStack {
                Background()

                Form {
                    // MARK: - Game Defaults
                    Section {
                        Picker("Game Type", selection: $defaultGameType) {
                            Text("Six").tag("six")
                            Text("Nine").tag("nine")
                        }
                        .onChange(of: defaultGameType) { _, newValue in
                            switch newValue {
                            case "six":
                                defaultMaxScore = 20
                            default:
                                defaultMaxScore = 100
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Score to Win: \(defaultMaxScore, format: .number.precision(.fractionLength(0)))")
                            Slider(
                                value: $defaultMaxScore,
                                in: defaultGameType == "nine" ? 0...200 : 0...100,
                                step: 10
                            )
                        }
                    } header: {
                        Text("Game Defaults")
                    }
                    .listRowBackground(Theme.surfaceSecondary)

                    // MARK: - Player Management
                    Section {
                        if players.isEmpty {
                            Text("No players yet")
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            ForEach(players) { player in
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(Theme.textSecondary)

                                    Text(player.name)
                                        .foregroundStyle(Theme.textPrimary)

                                    Spacer()

                                    Text("\(player.games.count) games")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .onDelete { indexSet in
                                if let index = indexSet.first {
                                    playerToDelete = players[index]
                                    showDeleteConfirmation = true
                                }
                            }
                        }
                    } header: {
                        Text("Players")
                    }
                    .listRowBackground(Theme.surfaceSecondary)

                    // MARK: - About
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .foregroundStyle(Theme.textSecondary)
                        }

                        HStack {
                            Text("Build")
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    } header: {
                        Text("About")
                    }
                    .listRowBackground(Theme.surfaceSecondary)
                }
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Player", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    playerToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let player = playerToDelete {
                        context.delete(player)
                        playerToDelete = nil
                    }
                }
            } message: {
                if let player = playerToDelete {
                    Text("Are you sure you want to delete \(player.name)? This will remove them from future games but won't affect past game records.")
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Game.self, inMemory: true)
}
