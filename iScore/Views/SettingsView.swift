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
    @Query(sort: \GamePreset.name) private var presets: [GamePreset]

    @AppStorage(GameDefaults.typeKey) private var defaultGameType = GameType.nine.rawValue
    @AppStorage(GameDefaults.targetKey) private var defaultMaxScore = Double(GameType.nine.defaultTarget)

    @AppStorage(OwnerIdentity.nameKey) private var ownerName = ""

    @AppStorage(LanguageSettings.appKey) private var appLanguage = AppLanguage.matching(.current).rawValue
    @AppStorage(LanguageSettings.voiceKey) private var voiceLanguage = ""

    @State private var pendingLanguage: AppLanguage?

    /// Changing this needs a relaunch, so it is staged rather than applied.
    private var appLanguageSelection: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: appLanguage) ?? .matching(.current) },
            set: { new in
                guard LanguageRelaunch.needsRelaunch(
                    changing: AppLanguage(rawValue: appLanguage) ?? .matching(.current),
                    to: new
                ) else { return }
                pendingLanguage = new
            }
        )
    }

    /// Takes effect immediately: it is only an identifier the recognizer and
    /// the synthesizer are built from.
    private var voiceLanguageSelection: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: voiceLanguage) ?? AppLanguage(rawValue: appLanguage) ?? .matching(.current) },
            set: { voiceLanguage = $0.rawValue }
        )
    }

    // In the App Group suite so the widget reads the same value.
    @AppStorage(LockScreenScoring.requireUnlockKey, store: AppGroup.defaults)
    private var requireUnlockToScore = false

    @AppStorage(VoiceOutput.speechKey) private var speaksAnswers = true
    @AppStorage(TableModeSettings.defaultKey) private var tableModeByDefault = false
    @Environment(TableModeSession.self) private var tableMode

    @State private var playerToDelete: Player?
    @State private var presetToDelete: GamePreset?
    @State private var editingPreset: GamePreset?
    @State private var isCreatingPreset = false

    private var isConfirmingPresetDelete: Binding<Bool> {
        Binding(get: { presetToDelete != nil }, set: { if !$0 { presetToDelete = nil } })
    }

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

                Text("Presets")
                    .duoLabel()
                    .padding(.top, 10)

                presetsCard

                Text("Table mode")
                    .duoLabel()
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $tableModeByDefault) {
                        Text("Start games in table mode")
                            .font(DuoFont.body)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .tint(Theme.teamA)
                    // Applies tonight, not only after the next launch.
                    .onChange(of: tableModeByDefault) { _, on in
                        tableMode.followDefault(on)
                    }

                    Text("The phone lies flat between the players: big scores, screen stays on.")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
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

                Text("Language")
                    .duoLabel()
                    .padding(.top, 10)

                VStack(spacing: 0) {
                    LanguageRow(
                        icon: "character.bubble.fill",
                        tint: Theme.learn,
                        title: "App language",
                        selection: appLanguageSelection
                    )

                    Rectangle().fill(Theme.divider).frame(height: 2)

                    LanguageRow(
                        icon: "waveform",
                        tint: Theme.teamB,
                        title: "Voice language",
                        selection: voiceLanguageSelection
                    )
                }
                .padding(.horizontal, 14)
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
        .alert(
            "Restart to change language?",
            isPresented: Binding(get: { pendingLanguage != nil }, set: { if !$0 { pendingLanguage = nil } }),
            presenting: pendingLanguage
        ) { language in
            Button("Close iScore") {
                LanguageRelaunch.apply(language, to: .standard)
                LanguageRelaunch.saveBeforeClosing(context)
                exit(0)
            }
            Button("Cancel", role: .cancel) { pendingLanguage = nil }
        } message: { language in
            Text("iScore will close. Open it again to see \(language.endonym). Your games are saved.")
        }
        .alert("Delete Preset", isPresented: isConfirmingPresetDelete, presenting: presetToDelete) { preset in
            Button("Delete", role: .destructive) {
                context.delete(preset)
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("This preset will be removed. Games already played stay.")
        }
        .sheet(item: $editingPreset) { preset in
            PresetEditorView(preset: preset)
        }
        .sheet(isPresented: $isCreatingPreset) {
            PresetEditorView(preset: nil)
        }
        .alert("Delete Player", isPresented: isConfirmingDelete, presenting: playerToDelete) { player in
            Button("Delete", role: .destructive) {
                context.delete(player)
            }
            Button("Cancel", role: .cancel) { }
        } message: { player in
            Text("Are you sure you want to delete \(player.name)? This will remove them from future games but won't affect past game records.")
        }
    }

    private var presetsCard: some View {
        let duplicates = PresetList.duplicates(in: presets)
        let known = players.map(\.name)
        return VStack(spacing: 0) {
            if presets.isEmpty {
                Text("No presets yet")
                    .font(DuoFont.body)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                ForEach(presets) { preset in
                    SettingsPresetRow(
                        setup: preset.setup,
                        notes: PresetRowNotes.notes(for: preset.setup,
                                                    isDuplicate: duplicates.contains { $0 === preset },
                                                    known: known),
                        onEdit: { editingPreset = preset },
                        onDelete: { presetToDelete = preset }
                    )
                    Rectangle().fill(Theme.divider).frame(height: 2)
                }
            }
            Button("New preset", systemImage: "plus") {
                isCreatingPreset = true
            }
            .font(DuoFont.body)
            .foregroundStyle(Theme.accentInk)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .duoCard()
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
    let title: LocalizedStringResource
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

/// A language picker row, shaped like the rows beside it.
private struct LanguageRow: View {

    let icon: String
    let tint: Color
    let title: LocalizedStringResource
    @Binding var selection: AppLanguage

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

            Picker(title, selection: $selection) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.endonym).tag(language)
                }
            }
            .pickerStyle(.menu)
            .font(DuoFont.body)
            .tint(Theme.accentInk)
            .accessibilityLabel(title)
        }
        .padding(.vertical, 6)
    }
}

/// A saved preset: its name and setup, anything wrong with it, edit and delete.
private struct SettingsPresetRow: View {

    let setup: PresetSetup
    let notes: [LocalizedStringResource]
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(setup.name)
                        .font(DuoFont.body)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("\(setup.gameType.title) · \(setup.target)")
                        .duoLabel()
                    ForEach(notes.indices, id: \.self) { index in
                        Text(notes[index])
                            .duoLabel(Theme.streak)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(setup.accessibilityLabel))
            .accessibilityValue(Text(notes.map { String(localized: $0) }.joined(separator: ", ")))
            .accessibilityHint(Text("Edit preset"))

            Button("Delete preset \(setup.name)", systemImage: "trash", action: onDelete)
                .labelStyle(.iconOnly)
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textMuted)
                .frame(minWidth: 36, minHeight: 36)
        }
        .padding(.vertical, 8)
    }
}
