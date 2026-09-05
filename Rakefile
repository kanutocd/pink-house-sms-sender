# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |task|
  task.libs << "test"
  task.libs << "lib"
  task.test_files = FileList["test/**/test_*.rb", "test/**/*_test.rb"]
end

require "rubocop/rake_task"
require "yard"
require "yard/rake/yardoc_task"

RuboCop::RakeTask.new do |task|
  task.options = ["--cache", "false"]
end

YARD::Rake::YardocTask.new(:yard) do |task|
  task.files = ["lib/**/*.rb"]
  task.options = ["--output-dir", "doc", "--readme", "README.md", "--markup", "markdown"]
end

desc "Validate RBS signatures"
task :rbs do
  sh "rbs validate"
end

desc "Enforce YARD documentation coverage"
task "yard:coverage" => :yard do
  output = `yard stats --no-progress --list-undoc --exclude sig`
  puts output
  coverage = output[/([0-9]+(?:\.[0-9]+)?)% documented/, 1]&.to_f
  abort "Could not determine YARD documentation coverage" unless coverage
  abort "YARD documentation coverage #{coverage}% is below 100%" if coverage < 100.0
end

desc "Run the test and lint quality gates"
task quality: %i[test rubocop rbs yard:coverage]

task default: :quality
