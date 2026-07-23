#!/usr/bin/env ruby

require "rubygems"

begin
  require "xcodeproj"
rescue LoadError
  cocoapods_homes = Dir[
    "/opt/homebrew/Cellar/cocoapods/*/libexec",
    "/usr/local/Cellar/cocoapods/*/libexec",
  ]
  cocoapods_home = cocoapods_homes.max_by do |path|
    Gem::Version.new(File.basename(File.dirname(path)).split("_").first)
  end
  raise unless cocoapods_home

  ENV["GEM_HOME"] = cocoapods_home
  ENV["GEM_PATH"] = cocoapods_home
  Gem.clear_paths
  require "xcodeproj"
end

mode = ARGV.fetch(0, nil)
project_path = ARGV.fetch(
  1,
  File.expand_path("../apps/mobile/ios/Runner.xcodeproj", __dir__)
)

unless mode == "exclude"
  warn "Usage: #{$PROGRAM_NAME} exclude [path-to-Runner.xcodeproj]"
  exit 64
end

project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |target| target.name == "Runner" }
abort "Runner target was not found" unless runner

watch_target_names = [
  "ccpocket Watch App",
  "ccpocket Watch Widget",
].freeze
watch_targets = project.targets.select do |target|
  watch_target_names.include?(target.name)
end

runner.copy_files_build_phases
  .select { |phase| phase.name == "Embed Watch Content" }
  .each(&:remove_from_project)

runner.dependencies
  .select { |dependency| watch_targets.include?(dependency.target) }
  .each(&:remove_from_project)

watch_targets.each(&:remove_from_project)
project.save

remaining_targets = project.targets.map(&:name)
unexpected_targets = watch_target_names & remaining_targets
abort "Failed to remove Watch targets: #{unexpected_targets.join(", ")}" unless unexpected_targets.empty?

if runner.copy_files_build_phases.any? { |phase| phase.name == "Embed Watch Content" }
  abort "Failed to remove Embed Watch Content phase"
end

puts "Configured iPhone-only Xcode project at #{project_path}"
