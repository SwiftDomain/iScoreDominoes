#!/usr/bin/env ruby
# frozen_string_literal: true

# Edits iScore.xcodeproj, which uses classic groups: every new or deleted
# Swift file must be registered here (Xcode does not pick up folders).
#
#   ruby scripts/xcodeproj.rb setup-tests
#   ruby scripts/xcodeproj.rb add <target> <repo-relative path>...
#   ruby scripts/xcodeproj.rb remove <repo-relative path>...
#
# Requires: gem install --user-install xcodeproj -v 1.27.0
# (1.28+ depends on a native gem that does not build against macOS system Ruby.)

gem 'xcodeproj', '~> 1.27.0'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'iScore.xcodeproj')
APP_TARGET = 'iScore'
TEST_TARGET = 'iScoreTests'
WIDGET_TARGET = 'iScoreWidgets'
APP_BUNDLE_ID = 'SwiftDomainUI.iScore'
EMBED_PHASE = 'Embed Foundation Extensions'

def project
  @project ||= Xcodeproj::Project.open(PROJECT_PATH)
end

def target_named(name)
  project.targets.find { |t| t.name == name } || abort("No target named #{name}")
end

def find_group(dir, create: false)
  dir.split('/').reject { |part| part.empty? || part == '.' }.reduce(project.main_group) do |parent, name|
    return nil if parent.nil?

    existing = parent.children.find { |c| c.isa == 'PBXGroup' && (c.path == name || c.display_name == name) }
    existing || (create ? parent.new_group(name, name) : nil)
  end
end

def setup_tests
  app = target_named(APP_TARGET)
  tests = project.targets.find { |t| t.name == TEST_TARGET }
  unless tests
    tests = project.new_target(:unit_test_bundle, TEST_TARGET, :ios, '26.0', project.products_group, :swift)
    tests.add_dependency(app)
  end
  remove_sdk_frameworks(tests)

  team =app.build_configurations.map { |c| c.build_settings['DEVELOPMENT_TEAM'] }.compact.first
  tests.build_configurations.each do |config|
    settings = config.build_settings
    settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'SwiftDomainUI.iScoreTests'
    settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/iScore.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/iScore'
    settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    settings['SWIFT_VERSION'] = '5.0'
    settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['DEVELOPMENT_TEAM'] = team if team
  end

  find_group(TEST_TARGET, create: true)
  project.save
  add_to_shared_scheme(tests)
end

# The widget extension that hosts the Lock Screen Live Activity. It shares an
# App Group with the app and must never link SwiftData: the app is the single
# owner of the store. Safe to re-run.
def setup_widget
  app = target_named(APP_TARGET)
  widget = project.targets.find { |t| t.name == WIDGET_TARGET }
  unless widget
    widget = project.new_target(:app_extension, WIDGET_TARGET, :ios, '26.0', project.products_group, :swift)
  end
  remove_sdk_frameworks(widget)

  team = app.build_configurations.map { |c| c.build_settings['DEVELOPMENT_TEAM'] }.compact.first
  widget.build_configurations.each do |config|
    settings = config.build_settings
    settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{APP_BUNDLE_ID}.Widgets"
    settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'iScore'
    # The NSExtension dict has no INFOPLIST_KEY_ equivalent, so it comes from
    # a real plist that Xcode merges with the generated one. Without it the
    # .appex is not a valid extension and the app will not install.
    settings['INFOPLIST_FILE'] = "#{WIDGET_TARGET}/Info.plist"
    settings.delete('INFOPLIST_KEY_NSExtensionPointIdentifier')
    settings['CODE_SIGN_ENTITLEMENTS'] = "#{WIDGET_TARGET}/#{WIDGET_TARGET}.entitlements"
    settings['SWIFT_VERSION'] = '5.0'
    settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
    settings['SKIP_INSTALL'] = 'YES'
    # An .appex with no version keys fails to install ("Simulator device
    # failed to install the application"), and the numbers must track the app.
    settings['MARKETING_VERSION'] = app_setting(app, 'MARKETING_VERSION') || '1.0'
    settings['CURRENT_PROJECT_VERSION'] = app_setting(app, 'CURRENT_PROJECT_VERSION') || '1'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['DEVELOPMENT_TEAM'] = team if team
  end

  app.build_configurations.each do |config|
    # ActivityKit refuses to start an activity without this.
    config.build_settings['INFOPLIST_KEY_NSSupportsLiveActivities'] = 'YES'
    # CFBundleURLTypes (the iscoredominoes:// scheme the Lock Screen falls
    # back to) has no INFOPLIST_KEY_ equivalent either.
    config.build_settings['INFOPLIST_FILE'] = "#{APP_TARGET}/Info.plist"
  end

  app.add_dependency(widget) unless app.dependencies.any? { |d| d.target == widget }
  embed_extension(app, widget)
  share_assets_with(widget)

  find_group(WIDGET_TARGET, create: true)
  project.save
end

# Copies the .appex into the app's PlugIns folder, which is what makes the
# widget ship with the app rather than merely build beside it.
def app_setting(app, key)
  app.build_configurations.map { |c| c.build_settings[key] }.compact.first
end

def embed_extension(app, widget)
  phase = app.copy_files_build_phases.find { |p| p.name == EMBED_PHASE }
  unless phase
    phase = app.new_copy_files_build_phase(EMBED_PHASE)
    phase.symbol_dst_subfolder_spec = :plug_ins
  end
  return if phase.files_references.include?(widget.product_reference)

  file = phase.add_file_reference(widget.product_reference)
  file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# `Color("teamA")` resolves against `Bundle.main`, which inside an extension is
# the extension's own bundle, so the widget needs the catalog too.
def share_assets_with(widget)
  ref = project.main_group.files.find { |f| f.path == 'Assets.xcassets' }
  return unless ref
  return if widget.resources_build_phase.files_references.include?(ref)

  widget.resources_build_phase.add_file_reference(ref)
end

# `new_target` links Foundation.framework by a path inside a pinned SDK
# (e.g. iPhoneOS18.0.sdk) that goes missing with newer Xcodes. Swift
# imports it implicitly, so drop it and the Frameworks/iOS groups it made.
def remove_sdk_frameworks(target)
  target.frameworks_build_phase.files.dup.each do |build_file|
    ref = build_file.file_ref
    next unless ref.respond_to?(:source_tree) && ref.source_tree == 'DEVELOPER_DIR' && ref.path.to_s.include?('.sdk/')

    build_file.remove_from_project
    ref.remove_from_project if ref.build_files.empty?
  end
  remove_if_empty(project.main_group.children.find { |c| c.isa == 'PBXGroup' && c.display_name == 'Frameworks' })
end

def remove_if_empty(group)
  return unless group

  group.groups.each { |child| remove_if_empty(child) }
  group.remove_from_project if group.children.empty?
end

def add_to_shared_scheme(tests)
  path = File.join(Xcodeproj::XCScheme.shared_data_dir(PROJECT_PATH), "#{APP_TARGET}.xcscheme")
  scheme = Xcodeproj::XCScheme.new(path)
  registered = scheme.test_action.testables.any? do |testable|
    testable.buildable_references.any? { |ref| ref.target_name == TEST_TARGET }
  end
  return if registered

  scheme.test_action.add_testable(Xcodeproj::XCScheme::TestAction::TestableReference.new(tests))
  scheme.save!
end

SOURCE_EXTENSIONS = %w[.swift .m .mm .c .cc .cpp].freeze

def add(target_name, paths)
  target = target_named(target_name)
  paths.each do |rel|
    abort("No such file: #{rel}") unless File.exist?(File.join(ROOT, rel))

    group = find_group(File.dirname(rel), create: true)
    name = File.basename(rel)
    ref = group.files.find { |f| f.path == name } || group.new_reference(name)
    # Compiled code goes to Sources; everything else (a string catalog, a
    # plist, an asset) is a resource. `add_file_references` cannot tell for a
    # type Xcode infers from the extension, and a .xcstrings in Sources is
    # silently never built into the app.
    phase = SOURCE_EXTENSIONS.include?(File.extname(name)) ? target.source_build_phase : target.resources_build_phase
    next if phase.files_references.include?(ref)

    phase.add_file_reference(ref)
  end
  project.save
end

# `KEY=value` on every configuration of a target. Build settings are the right
# home for anything with an INFOPLIST_KEY_ equivalent (see iScore/Info.plist),
# and project.pbxproj is never hand-edited.
def set_settings(target_name, assignments)
  target = target_named(target_name)
  assignments.each do |assignment|
    key, value = assignment.split('=', 2)
    abort("Expected KEY=value, got: #{assignment}") if value.nil?

    target.build_configurations.each { |config| config.build_settings[key] = value }
  end
  project.save
end

def remove(paths)
  paths.each do |rel|
    group = find_group(File.dirname(rel))
    ref = group&.files&.find { |f| f.path == File.basename(rel) }
    next unless ref

    ref.build_files.each(&:remove_from_project)
    ref.remove_from_project
  end
  project.save
end

case ARGV.shift
when 'setup-tests' then setup_tests
when 'setup-widget' then setup_widget
when 'add' then add(ARGV.shift, ARGV)
when 'set' then set_settings(ARGV.shift, ARGV)
when 'remove' then remove(ARGV)
else abort('usage: xcodeproj.rb setup-tests | setup-widget | add <target> <path>... | set <target> KEY=value... | remove <path>...')
end
