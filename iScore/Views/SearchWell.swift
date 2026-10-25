//
//  SearchWell.swift
//  iScore
//
//  Gray search field with a magnifying glass and a clear button.
//

import SwiftUI

struct SearchWell: View {

    let prompt: LocalizedStringResource
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.textMuted)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(DuoFont.body)
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") {
                    text = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Theme.surfaceSecondary, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.divider, lineWidth: 2))
    }
}

#Preview {
    @Previewable @State var text = ""
    SearchWell(prompt: "Search players", text: $text)
        .padding()
}
