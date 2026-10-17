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

def add(target_name, paths)
  target = target_named(target_name)
  paths.each do |rel|
    abort("No such file: #{rel}") unless File.exist?(File.join(ROOT, rel))

    group = find_group(File.dirname(rel), create: true)
    name = File.basename(rel)
    ref = group.files.find { |f| f.path == name } || group.new_reference(name)
    target.add_file_references([ref]) unless target.source_build_phase.files_references.include?(ref)
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
when 'add' then add(ARGV.shift, ARGV)
when 'remove' then remove(ARGV)
else abort('usage: xcodeproj.rb setup-tests | add <target> <path>... | remove <path>...')
end
