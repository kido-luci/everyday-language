#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds (or repairs) the iOS Share Extension target in ios/Runner.xcodeproj.
#
#   ruby tool/ios_share_extension.rb
#
# The extension is what puts Everyday Language in the iOS share sheet, so a
# word selected in Safari can be captured without leaving the page. Xcode
# normally creates this target through File → New → Target; doing it in a
# script instead keeps the change reviewable, keeps `project.pbxproj` out of
# hand-editing range, and means a fresh scaffold can be brought back to this
# state with one command.
#
# Idempotent: run it as often as you like. It creates what is missing and
# corrects what has drifted.
#
# Sources under `ios/Share Extension/` are committed and are not touched here;
# this script only wires them into the project.

require 'xcodeproj'

PROJECT_PATH = 'ios/Runner.xcodeproj'
EXTENSION_NAME = 'Share Extension'
APP_BUNDLE_ID = 'com.lucistudio.everydaylanguage'
APP_GROUP_ID = "group.#{APP_BUNDLE_ID}"
DEPLOYMENT_TARGET = '15.0'

# Files the extension target owns, relative to `ios/`.
SOURCES = ["#{EXTENSION_NAME}/ShareViewController.swift"].freeze
RESOURCES = ["#{EXTENSION_NAME}/Base.lproj/MainInterface.storyboard"].freeze

abort "Run me from the repository root (#{PROJECT_PATH} not found)." unless Dir.exist?(PROJECT_PATH)

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'No Runner target.'

extension = project.targets.find { |t| t.name == EXTENSION_NAME }
if extension
  puts "• '#{EXTENSION_NAME}' target already present — checking its settings"
else
  puts "• creating the '#{EXTENSION_NAME}' target"
  extension = project.new_target(
    :app_extension, EXTENSION_NAME, :ios, DEPLOYMENT_TARGET
  )
end

# ── The files ────────────────────────────────────────────────────────────────
group = project.main_group.find_subpath(EXTENSION_NAME, true)
group.set_source_tree('SOURCE_ROOT')
group.set_path(EXTENSION_NAME)

def file_ref(project, group, path)
  name = File.basename(path)
  group.files.find { |f| f.display_name == name } ||
    group.new_reference(path.sub(%r{^[^/]+/}, ''))
end

# The app's bundle identifier on a given configuration.
#
# It is not one value: each flavor has its own (`…everydaylanguage.dev`,
# `.staging`, and the bare id for prod), and the flavored configurations do not
# carry it in the target at all — they leave it to the flavor's xcconfig. Both
# places have to be read, or every flavor but prod comes back wrong.
def app_bundle_id(runner, config_name)
  config = runner.build_configurations.find { |c| c.name == config_name }
  return nil unless config

  from_target = config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
  return from_target if from_target

  xcconfig = config.base_configuration_reference&.real_path
  return nil unless xcconfig&.exist?

  File.read(xcconfig)[/^\s*PRODUCT_BUNDLE_IDENTIFIER\s*=\s*(\S+)/, 1]
end

SOURCES.each do |path|
  ref = file_ref(project, group, path)
  extension.source_build_phase.add_file_reference(ref, true)
end

RESOURCES.each do |path|
  # Keep the storyboard in its own Base.lproj group so the built bundle finds
  # it where NSExtensionMainStoryboard expects.
  lproj = group.find_subpath('Base.lproj', true)
  lproj.set_source_tree('SOURCE_ROOT')
  lproj.set_path("#{EXTENSION_NAME}/Base.lproj")
  ref = lproj.files.find { |f| f.display_name == File.basename(path) } ||
        lproj.new_reference(File.basename(path))
  extension.resources_build_phase.add_file_reference(ref, true)
end

# Info.plist and the entitlements are referenced by build settings, not built,
# but they belong in the group so they are visible in Xcode.
[["#{EXTENSION_NAME}/Info.plist", 'Info.plist'],
 ["#{EXTENSION_NAME}/#{EXTENSION_NAME}.entitlements", "#{EXTENSION_NAME}.entitlements"]].each do |_, name|
  group.files.find { |f| f.display_name == name } || group.new_reference(name)
end

# ── Build settings, on every configuration ───────────────────────────────────
extension.build_configurations.each do |config|
  # Xcode refuses to embed an extension whose bundle identifier is not prefixed
  # by the app's own, and the app's own changes per flavor. Hard-coding the
  # prod id here builds prod and fails every other flavor with "Embedded
  # binary's bundle identifier is not prefixed with the parent app's bundle
  # identifier" — which is exactly what ships to CI, since CI builds dev.
  app_id = app_bundle_id(runner, config.name) ||
           abort("No bundle identifier for Runner on #{config.name}.")

  config.build_settings.merge!(
    'PRODUCT_BUNDLE_IDENTIFIER' => "#{app_id}.ShareExtension",
    'PRODUCT_NAME' => EXTENSION_NAME,
    'INFOPLIST_FILE' => "#{EXTENSION_NAME}/Info.plist",
    'CODE_SIGN_ENTITLEMENTS' => "#{EXTENSION_NAME}/#{EXTENSION_NAME}.entitlements",
    'IPHONEOS_DEPLOYMENT_TARGET' => DEPLOYMENT_TARGET,
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'SKIP_INSTALL' => 'YES',
    # Read by the plugin on both sides to find the shared container.
    'CUSTOM_GROUP_ID' => APP_GROUP_ID,
    # The app builds without a signing team; the extension must match or the
    # simulator build fails on the extension alone.
    'CODE_SIGN_STYLE' => 'Automatic',
    # Where the extension looks for the frameworks at *runtime*.
    #
    # The Podfile gives it `inherit! :search_paths`, so it links against the
    # pods but does not carry copies of them — they live in the app's
    # Frameworks folder, two directories above the .appex executable. Without
    # the second path the extension builds and installs perfectly and then
    # dies the instant it is tapped, with "Library not loaded:
    # @rpath/FBLPromises.framework/FBLPromises" and no visible error: the
    # share sheet simply does nothing.
    'LD_RUNPATH_SEARCH_PATHS' => [
      '$(inherited)',
      '@executable_path/Frameworks',
      '@executable_path/../../Frameworks'
    ]
  )
end

# Runner needs the same group id, and its own entitlement for the container.
runner.build_configurations.each do |config|
  config.build_settings['CUSTOM_GROUP_ID'] = APP_GROUP_ID
end

# ── Base configurations, one per build configuration ─────────────────────────
# CocoaPods points the extension straight at its own xcconfig, which does not
# include Flutter's Generated.xcconfig — so $(FLUTTER_BUILD_NAME) and
# $(FLUTTER_BUILD_NUMBER) do not resolve, Xcode drops the empty keys, and the
# .appex ships with no CFBundleVersion. It builds and runs; it is rejected at
# App Store submission.
#
# Every configuration gets one, flavors included. Wiring only Debug/Release/
# Profile would leave exactly the configurations that ship — Release-prod and
# friends — with the bug still in them, and passing on the one configuration
# nobody releases from.
flutter_group = project.main_group.find_subpath('Flutter', true)
extension.build_configurations.each do |config|
  name = config.name
  file = "ios/Flutter/ShareExtension#{name}.xcconfig"
  pods = "Pods/Target Support Files/Pods-#{EXTENSION_NAME}/" \
         "Pods-#{EXTENSION_NAME}.#{name.downcase}.xcconfig"

  File.write(file, <<~XCCONFIG)
    // Generated by tool/ios_share_extension.rb — do not edit by hand.
    //
    // Base configuration for the #{EXTENSION_NAME} target on #{name}, mirroring
    // what Flutter generates for Runner: the pods the extension inherits, plus
    // Generated.xcconfig so $(FLUTTER_BUILD_NAME) and $(FLUTTER_BUILD_NUMBER)
    // resolve here too. Without the second include the extension builds fine
    // and ships with no CFBundleVersion, which fails only at submission.
    #include? "#{pods}"
    #include "Generated.xcconfig"
  XCCONFIG

  # The Flutter group carries no path of its own, so each child holds the whole
  # path from the project directory — a bare basename resolves to ios/ and the
  # build cannot open the file.
  path = "Flutter/ShareExtension#{name}.xcconfig"
  ref = flutter_group.files.find { |f| f.display_name == File.basename(path) } ||
        flutter_group.new_reference(path)
  ref.path = path
  ref.source_tree = '<group>'
  config.base_configuration_reference = ref
end

# ── Runner depends on it, and embeds it ──────────────────────────────────────
runner.add_dependency(extension) unless runner.dependencies.any? { |d| d.target == extension }

embed = runner.build_phases.find do |phase|
  phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    phase.name == 'Embed Foundation Extensions'
end
unless embed
  embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
end
unless embed.files_references.include?(extension.product_reference)
  build_file = embed.add_file_reference(extension.product_reference, true)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# The extension must be embedded *before* Flutter's "Thin Binary" script runs,
# or the Swift module the extension imports is not there yet and the build
# fails with "no such module 'receive_sharing_intent'".
thin = runner.build_phases.index { |p| p.respond_to?(:name) && p.name.to_s.include?('Thin Binary') }
embed_at = runner.build_phases.index(embed)
if thin && embed_at && embed_at > thin
  puts '• moving "Embed Foundation Extensions" above "Thin Binary"'
  runner.build_phases.delete_at(embed_at)
  runner.build_phases.insert(thin, embed)
end

project.save
puts "✓ #{PROJECT_PATH} updated (app group #{APP_GROUP_ID})"
