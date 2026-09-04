# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  enable_coverage :branch
  minimum_coverage line: 99, branch: 99
  coverage_dir "coverage"
  add_filter "/test/"
  add_filter "version.rb"
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "sms_sender"
require "minitest/autorun"
