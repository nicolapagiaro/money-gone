# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe 'Pipeline totals' do
  it 'categorizes by includes rule before llm and skips llm for matched rows' do
    fake_llm = instance_double(MoneyGone::LlmClient)
    expect(fake_llm).to receive(:categorize).once.and_return(
      { 'category' => 'Altro', 'confidence' => 0.9, 'suggested_new_category' => nil }
    )

    tempfile = Tempfile.new(['stmt_rules', '.csv'])
    tempfile.write <<~CSV
      Data,Importo EUR,Descrizione
      2026-01-15,"-25,00",Esselunga Milano
      2026-01-16,"-12,00",Spesa generica
    CSV
    tempfile.flush

    loader = instance_double(MoneyGone::ConfigLoader)
    allow(loader).to receive(:load_all).and_return(
      {
        categories: ['Supermercato e alimentari', 'Altro'],
        rules: {
          'transfer' => { 'enabled' => false },
          'categorization' => {
            'confidence_threshold' => 0.42,
            'parallel_jobs' => 1,
            'description_category_includes' => {
              'esselunga' => 'Supermercato e alimentari'
            }
          }
        },
        lmstudio: {}
      }
    )

    root = File.expand_path('../..', __dir__)
    result = Dir.chdir(root) do
      MoneyGone::Pipeline.new(root: root, llm: fake_llm, loader: loader).run(
        [{ bank_id: 't', path: tempfile.path }]
      )
    end

    expect(result[:rows].size).to eq(2)
    matched = result[:rows].find { |r| r[:description_clean].to_s.include?('esselunga') }
    unmatched = result[:rows].find { |r| r[:description_clean] == 'spesa generica' }
    expect(matched[:category]).to eq('Supermercato e alimentari')
    expect(matched[:category_source]).to eq('rule_includes')
    expect(matched[:category_confidence]).to eq(1.0)
    expect(unmatched[:category]).to eq('Altro')
  ensure
    tempfile&.close!
  end

  it 'sums multiple rows into separate category buckets (no last-row overwrite)' do
    fake_llm = instance_double(MoneyGone::LlmClient)
    allow(fake_llm).to receive(:categorize) do |tx|
      if tx[:description_clean].to_s.include?('bar')
        { 'category' => 'Bar e caffe', 'confidence' => 0.92, 'suggested_new_category' => nil }
      else
        { 'category' => 'Altro', 'confidence' => 0.9, 'suggested_new_category' => nil }
      end
    end

    tempfile = Tempfile.new(['stmt', '.csv'])
    tempfile.write <<~CSV
      Data,Importo EUR,Descrizione
      2026-01-15,"-3,50",Pagamento bar
      2026-01-16,"-12,00",Spesa generica
    CSV
    tempfile.flush

    root = File.expand_path('../..', __dir__)
    result = Dir.chdir(root) do
      MoneyGone::Pipeline.run(
        [{ bank_id: 't', path: tempfile.path }],
        root: root,
        llm: fake_llm
      )
    end

    expect(result[:totals]['Bar e caffè']).to be_within(0.01).of(-3.5)
    expect(result[:totals]['Altro']).to be_within(0.01).of(-12.0)
    expect(result[:rows].size).to eq(2)
    expect(result[:flow_totals][:entrate]).to be_within(0.01).of(0.0)
    expect(result[:flow_totals][:uscite]).to be_within(0.01).of(-15.5)
    expect(result[:flow_totals][:netto]).to be_within(0.01).of(-15.5)
  ensure
    tempfile&.close!
  end

  it 'computes entrate/uscite excluding transfers by raw description rule' do
    fake_llm = instance_double(MoneyGone::LlmClient)
    allow(fake_llm).to receive(:categorize).and_return(
      { 'category' => 'Altro', 'confidence' => 0.9, 'suggested_new_category' => nil }
    )

    f_a = Tempfile.new(['stmt_a', '.csv'])
    f_a.write <<~CSV
      Data,Importo EUR,Descrizione
      2026-01-15,"-100,00",Versamento su conto deposito
    CSV
    f_a.flush

    f_b = Tempfile.new(['stmt_b', '.csv'])
    f_b.write <<~CSV
      Data,Importo EUR,Descrizione
      2026-01-15,"100,00",Stipendio
      2026-01-16,"-5,00",Caffè
    CSV
    f_b.flush

    root = File.expand_path('../..', __dir__)
    result = Dir.chdir(root) do
      MoneyGone::Pipeline.run(
        [
          { bank_id: 'a', path: f_a.path },
          { bank_id: 'b', path: f_b.path }
        ],
        root: root,
        llm: fake_llm
      )
    end

    expect(result[:transfers].size).to eq(1)
    expect(result[:flow_totals][:entrate]).to be_within(0.01).of(100.0)
    expect(result[:flow_totals][:uscite]).to be_within(0.01).of(-5.0)
    expect(result[:flow_totals][:netto]).to be_within(0.01).of(95.0)
  ensure
    f_a&.close!
    f_b&.close!
  end

  it 'computes flusso di cassa netto as somma algebrica (entrate + uscite firmati)' do
    fake_llm = instance_double(MoneyGone::LlmClient)
    allow(fake_llm).to receive(:categorize).and_return(
      { 'category' => 'Altro', 'confidence' => 0.9, 'suggested_new_category' => nil }
    )

    tempfile = Tempfile.new(['stmt_mix', '.csv'])
    tempfile.write <<~CSV
      Data,Importo EUR,Descrizione
      2026-01-10,"100,00",Stipendio
      2026-01-11,"-30,50",Bolletta
    CSV
    tempfile.flush

    root = File.expand_path('../..', __dir__)
    result = Dir.chdir(root) do
      MoneyGone::Pipeline.run(
        [{ bank_id: 'solo', path: tempfile.path }],
        root: root,
        llm: fake_llm
      )
    end

    expect(result[:flow_totals][:entrate]).to be_within(0.01).of(100.0)
    expect(result[:flow_totals][:uscite]).to be_within(0.01).of(-30.5)
    expect(result[:flow_totals][:netto]).to be_within(0.01).of(69.5)
  ensure
    tempfile&.close!
  end

  it 'does not exclude opposite movements without matching raw description rule' do
    fake_llm = instance_double(MoneyGone::LlmClient)
    allow(fake_llm).to receive(:categorize).and_return(
      { 'category' => 'Altro', 'confidence' => 0.9, 'suggested_new_category' => nil }
    )

    tempfile = Tempfile.new(['stmt_same', '.csv'])
    tempfile.write <<~CSV
      Data,Importo EUR,Descrizione
      2026-01-10,"-200,00",Pagamento carta
      2026-01-10,"200,00",Rimborso
      2026-01-11,"-10,00",Spesa reale
    CSV
    tempfile.flush

    root = File.expand_path('../..', __dir__)
    result = Dir.chdir(root) do
      MoneyGone::Pipeline.run(
        [{ bank_id: 'solo', path: tempfile.path }],
        root: root,
        llm: fake_llm
      )
    end

    expect(result[:transfers].size).to eq(0)
    expect(result[:flow_totals][:entrate]).to be_within(0.01).of(200.0)
    expect(result[:flow_totals][:uscite]).to be_within(0.01).of(-210.0)
    expect(result[:flow_totals][:netto]).to be_within(0.01).of(-10.0)
  ensure
    tempfile&.close!
  end

  it 'excludes cross-bank opposite movements with same amount and date' do
    fake_llm = instance_double(MoneyGone::LlmClient)
    allow(fake_llm).to receive(:categorize).and_return(
      { 'category' => 'Altro', 'confidence' => 0.9, 'suggested_new_category' => nil }
    )

    f_a = Tempfile.new(['stmt_a_cross', '.csv'])
    f_a.write <<~CSV
      Data,Importo EUR,Descrizione
      2026-01-15,"-100,00",Bonifico uscita verso banca B
    CSV
    f_a.flush

    f_b = Tempfile.new(['stmt_b_cross', '.csv'])
    f_b.write <<~CSV
      Data,Importo EUR,Descrizione
      2026-01-15,"100,00",Bonifico entrata da banca A
      2026-01-16,"-5,00",Caffè
    CSV
    f_b.flush

    root = File.expand_path('../..', __dir__)
    result = Dir.chdir(root) do
      MoneyGone::Pipeline.run(
        [
          { bank_id: 'a', path: f_a.path },
          { bank_id: 'b', path: f_b.path }
        ],
        root: root,
        llm: fake_llm
      )
    end

    expect(result[:transfers].size).to eq(2)
    expect(result[:transfers].map { |t| t[:excluded_reason] }.uniq).to eq(['internal_transfer_cross_bank_amount_date'])
    expect(result[:flow_totals][:entrate]).to be_within(0.01).of(0.0)
    expect(result[:flow_totals][:uscite]).to be_within(0.01).of(-5.0)
    expect(result[:flow_totals][:netto]).to be_within(0.01).of(-5.0)
  ensure
    f_a&.close!
    f_b&.close!
  end
end
