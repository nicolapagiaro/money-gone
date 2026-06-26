# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'CLI boot' do
  it 'shows help' do
    stdout, status = Open3.capture2('ruby bin/money-gone --help')
    expect(status.success?).to be(true)
    expect(stdout).to include('analyze')
  end
end
