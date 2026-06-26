# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MoneyGone::LlmClient do
  let(:client) { described_class.new(base_url: 'http://localhost:1234/v1', model: 'qwen3.2 8b') }

  def stub_llm_chat(client, temperature:, response_content:)
    fake_chat = instance_double('RubyLLM::Chat')
    fake_response = instance_double('RubyLLM::Message', content: response_content)
    allow(fake_chat).to receive_messages(with_schema: fake_chat, add_message: fake_chat, ask: fake_response)
    allow(client).to receive(:llm_chat).with(temperature: temperature).and_return(fake_chat)
    fake_chat
  end

  it 'parses strict JSON response for categorization' do
    payload = '{"category":"Spesa","confidence":0.91,"rationale_short":"market","suggested_new_category":null}'
    expect(client.parse_json(payload)['category']).to eq('Spesa')
  end

  it 'classifies a transaction via JSON from chat' do
    tx = {
      id: 'x:1',
      bank_id: 'x',
      booking_date: '2026-05-01',
      amount_signed: -12.5,
      description_clean: 'supermercato'
    }
    stub_llm_chat(
      client,
      temperature: 0.28,
      response_content: {
        'category' => 'Spesa',
        'confidence' => 0.88,
        'rationale_short' => 'spesa alimentare',
        'suggested_new_category' => nil
      }
    )
    out = client.categorize(tx, allowed_categories: %w[Spesa Altro], include_suggestions: true)
    expect(out['category']).to eq('Spesa')
    expect(out['confidence']).to be_within(0.01).of(0.88)
  end

  it 'uses the compact prompt with lower temperature for fast categorization' do
    tx = {
      id: 'x:1',
      bank_id: 'x',
      booking_date: '2026-05-01',
      amount_signed: -12.5,
      description_clean: 'tariffa atm'
    }
    fake_chat = stub_llm_chat(
      client,
      temperature: 0.2,
      response_content: { 'category' => 'Altro', 'confidence' => 0.6 }
    )
    expect(fake_chat).to receive(:with_schema).with(MoneyGone::LlmPrompts.categorization_schema_fast).and_return(fake_chat)
    out = client.categorize(tx, allowed_categories: %w[Spesa Altro], include_suggestions: false)
    expect(out['category']).to eq('Altro')
  end
end
