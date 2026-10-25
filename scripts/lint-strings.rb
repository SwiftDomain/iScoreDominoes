#!/usr/bin/env ruby
# frozen_string_literal: true

# Fails the build on user-visible copy that will never reach the String
# Catalog, so it can never be translated.
#
#   ruby scripts/lint-strings.rb [--quiet]
#
# `SWIFT_EMIT_LOC_STRINGS = YES` means a literal written directly inside
# Text("…"), Button("…"), Label("…", …) or .accessibilityLabel("…") is
# extracted at build time and needs no help. What does NOT extract is copy
# assembled into a `String` first and handed to a view as a variable — the
# bug this catches, which shipped twice during the two-language work:
# `HomeCardView.title: String` left the Home tiles in English, and
# `Game.headline: String` left the scoreboard in English.
#
# So the rule is about TYPES, not about literals: a stored property or
# function that carries user-visible copy must be `LocalizedStringResource`,
# never `String`.

ROOT = File.expand_path('..', __dir__)
QUIET = ARGV.include?('--quiet')

# Property and parameter names that carry copy a person reads.
COPY_NAMES = %w[title subtitle label message prompt hint headline summary
                caption placeholder detail explanation notice].freeze

# `name`/`value` hold data (player names, scores); `text` is ambiguous and is
# checked by name only where it is a view parameter.
DECLARATION = /^\s*(?:private\s+|fileprivate\s+|public\s+)?(?:static\s+)?(?:let|var)\s+(#{COPY_NAMES.join('|')})\s*:\s*String\b/
FUNCTION = /^\s*(?:private\s+|fileprivate\s+|public\s+)?(?:static\s+)?func\s+\w*(?:#{COPY_NAMES.join('|')})\w*\s*\([^)]*\)\s*->\s*String\b/i

# Lines that are legitimately String, each with the reason it is exempt.
# Everything here returns text that has ALREADY been resolved — it composes
# String(localized:) pieces, or carries a runtime value — so it is not a
# lookup key and `LocalizedStringResource` would buy nothing.
ALLOW = [
  # Resolved spoken text handed to the banner, not a key.
  %r{iScore/Views/GameView\.swift.*let text: String},
  # A player's own name is data and is never translated.
  /displayName|PlayerName|playerName/,
  # A formatted date: already rendered in the app's locale by FormatStyle.
  %r{iScore/Model/GameList\.swift.*var title: String},
  # These compose String(localized:) fragments with a runtime error's
  # description, so they return finished text rather than a key.
  %r{iScore/Model/GameSetup\.swift.*func \w*(xplanation|otice)},
  # Same: the bar's title and detail are assembled from localized pieces
  # plus the live transcript.
  %r{iScore/Views/VoiceScoreBar\.swift.*(func (title|detail)|var (title|detail))},
  %r{iScore/Views/VoiceGameSheet\.swift.*var prompt: String}
].freeze

offenders = []

Dir.glob(File.join(ROOT, 'iScore/**/*.swift')).sort.each do |path|
  rel = path.sub("#{ROOT}/", '')
  File.readlines(path, encoding: 'UTF-8').each_with_index do |line, i|
    next if line.strip.start_with?('//')
    next unless line.match?(DECLARATION) || line.match?(FUNCTION)
    next if ALLOW.any? { |a| "#{rel} #{line}".match?(a) }

    offenders << "#{rel}:#{i + 1}: #{line.strip}"
  end
end

if offenders.empty?
  puts 'lint-strings: no un-localizable copy found' unless QUIET
  exit 0
end

warn 'lint-strings: user-visible copy typed as String cannot reach the catalog.'
warn 'Use LocalizedStringResource, or add a reason to ALLOW in this script.'
warn ''
offenders.each { |o| warn "  #{o}" }
exit 1
