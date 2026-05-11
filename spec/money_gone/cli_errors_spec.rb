# frozen_string_literal: true

require "spec_helper"

RSpec.describe "cli errors" do
  it "fails with non-zero when LM Studio is unavailable" do
    root = File.expand_path("../..", __dir__)
    out = `cd #{root} && MONEY_GONE_LLM_FAIL=1 ruby bin/money-gone analyze a:spec/fixtures/bank_a.csv 2>&1`
    expect($?.exitstatus).not_to eq(0)
    expect(out).to include("LM Studio unavailable")
  end

  it "reports schema mapping problems" do
    root = File.expand_path("../..", __dir__)
    out = `cd #{root} && ruby bin/money-gone analyze a:spec/fixtures/bad_headers.csv 2>&1`
    expect($?.exitstatus).to eq(3)
    expect(out).to include("Schema mapping error")
  end
end
