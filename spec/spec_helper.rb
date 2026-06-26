# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'money_gone'

require_relative 'support/movement_helpers'

RSpec.configure do |config|
  config.include MovementHelpers
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.disable_monkey_patching!
end
