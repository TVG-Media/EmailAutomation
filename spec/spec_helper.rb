# frozen_string_literal: true


if ENV['CI'] == 'true'
  require 'simplecov'
  SimpleCov.start
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require 'caffeinate'
require 'pry'
require 'pry-rails'
require 'timecop'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.around(:example) do |example|
    Timecop.freeze("01/01/2020") { example.call }
  end
end
