//
//  SettingsView.swift
//  iScore
//
//  Settings sheet: New Game defaults, saved players, and app info.
//

import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \Player.name) private var players: [Player]

    @AppStorage(GameDefaults.typeKey) private var defaultGameType = GameType.nine.rawValue
    @AppStorage(GameDefaults.targetKey) private var defaultMaxScore = Double(GameType.nine.defaultTarget)

    @AppStorage(OwnerIdentity.nameKey) private var ownerName = ""

    // In the App Group suite so the widget reads the same value.
    @AppStorage(LockScreenScoring.requireUnlockKey, store: AppGroup.defaults)
    private var requireUnlockToScore = false

    @AppStorage(VoiceOutput.speechKey) private var speaksAnswers = true

    @State private var playerToDelete: Player?

    private var isConfirmingDelete: Binding<Bool> {
        Binding(get: { playerToDelete != nil }, set: { if !$0 { playerToDelete = nil } })
    }

    private var gameType: GameType {
        GameType(rawValue: defaultGameType) ?? .nine
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SheetHeader(title: "Settings")
                    .padding(.bottom, 4)

                Text("New game defaults")
                    .duoLabel()

                VStack(spacing: 12) {
                    GameTypePicker(selection: gameType, compact: true, onSelect: chooseType)

                    HStack(spacing: 8) {
                        Text("First to")
                            .font(DuoFont.body)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 8)
                        TargetStepper(target: gameType.clampedTarget(defaultMaxScore), gameType: gameType, compact: true) {
                            defaultMaxScore = Double($0)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .duoCard()

                Text("Players · \(players.count)")
                    .duoLabel()
                    .padding(.top, 10)

                VStack(spacing: 0) {
                    if players.isEmpty {
                        Text("No players yet")
                            .font(DuoFont.body)
                            .foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    } else {
                        OwnerRow(names: players.map(\.name), stored: $ownerName)
                        Rectangle().fill(Theme.divider).frame(height: 2)
                        ForEach(players) { player in
                            SettingsPlayerRow(player: player, isLast: player.persistentModelID == players.last?.persistentModelID) {
                                playerToDelete = player
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .duoCard()

                Text("Lock Screen")
                    .duoLabel()
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $requireUnlockToScore) {
                        Text("Require unlock to score")
                            .font(DuoFont.body)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .tint(Theme.teamB)

                    Text("Lock Screen buttons will open the app instead of scoring straight away.")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .duoCard()

                Text(String(localized: "Voice"))
                    .duoLabel()
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.learn)
                            .accessibilityHidden(true)

                        Text(String(localized: "Speak answers"))
                            .font(DuoFont.body)
                            .foregroundStyle(Theme.textPrimary)

                        Spacer(minLength: 8)

                        Toggle(String(localized: "Speak answers"), isOn: $speaksAnswers)
                            .labelsHidden()
                            .tint(Theme.teamA)
                    }

                    Text(String(localized: "Answers are always shown on screen. Silent mode also silences them."))
                        .font(DuoFont.body)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .duoCard()

                Text("About")
                    .duoLabel()
                    .padding(.top, 10)

                VStack(spacing: 0) {
                    AboutRow(icon: "checkmark.icloud.fill", tint: Theme.teamA, title: "iCloud sync", value: "On", valueColor: Theme.accentInk)
                    Rectangle().fill(Theme.divider).frame(height: 2)
                    AboutRow(icon: "info.circle.fill", tint: Theme.textMuted, title: "Version", value: Self.version, valueColor: Theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .duoCard()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Background())
        // `isPresented:presenting:` rather than `item:` — the `item:` overload
        // only exists in the newest SDK and breaks the Xcode 26 CI build.
        .alert("Delete Player", isPresented: isConfirmingDelete, presenting: playerToDelete) { player in
            Button("Delete", role: .destructive) {
                context.delete(player)
            }
            Button("Cancel", role: .cancel) { }
        } message: { player in
            Text("Are you sure you want to delete \(player.name)? This will remove them from future games but won't affect past game records.")
        }
    }

    /// "2.0 (14)"
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    /// Switching type resets the default target to that type's usual value.
    private func chooseType(_ type: GameType) {
        defaultGameType = type.rawValue
        defaultMaxScore = Double(type.defaultTarget)
    }
}

/// A saved player: avatar, name, game count, delete.
private struct SettingsPlayerRow: View {

    let player: Player
    let isLast: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PlayerAvatar(name: player.name)

            Text(player.name)
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(GameList.countLabel((player.games ?? []).count))
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textMuted)

            Button("Delete \(player.name)", systemImage: "trash", action: onDelete)
                .labelStyle(.iconOnly)
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textMuted)
                .frame(minWidth: 36, minHeight: 36)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Theme.divider).frame(height: 2)
            }
        }
    }
}

/// "That's me": which saved player owns this phone, or Nobody.
private struct OwnerRow: View {

    let names: [String]
    @Binding var stored: String

    /// The saved player's own spelling, or "" (Nobody) when the stored name no longer exists.
    private var selection: Binding<String> {
        Binding(
            get: { OwnerIdentity.resolve(stored, known: names) ?? "" },
            set: { stored = $0 }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill")
                .font(.title3)
                .foregroundStyle(Theme.teamA)
                .accessibilityHidden(true)

            Text("That's me")
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)

            Spacer(minLength: 8)

            Picker("That's me", selection: selection) {
                Text("Nobody").tag("")
                ForEach(names, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)
            .font(DuoFont.body)
            .tint(Theme.accentInk)
            .accessibilityLabel("That's me")
        }
        .padding(.vertical, 6)
    }
}

/// Icon, title, trailing value.
private struct AboutRow: View {

    let icon: String
    let tint: Color
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)

            Spacer(minLength: 8)

            Text(value)
                .font(DuoFont.body)
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return SettingsView()
            .modelContainer(previewer.container)
            .fontDesign(.rounded)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
