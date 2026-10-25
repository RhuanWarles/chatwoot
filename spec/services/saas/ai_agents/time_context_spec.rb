require 'rails_helper'

RSpec.describe Saas::AiAgents::TimeContext do
  let(:instant) { Time.utc(2026, 10, 24, 23, 30, 0) }

  it 'formats the current time with the configured offset and guidance' do
    context = described_class.message('America/Sao_Paulo', now: instant)

    expect(context).to include('Data e hora atuais: 2026-10-24T20:30:00-03:00')
    expect(context).to include('Fuso horário do assistente: America/Sao_Paulo')
    expect(context).to include('hoje, ontem, anteontem')
  end

  it 'uses timezone rules when two agents see different local dates' do
    sao_paulo = described_class.message('America/Sao_Paulo', now: instant)
    lisbon = described_class.message('Europe/Lisbon', now: instant)

    expect(sao_paulo).to include('2026-10-24T20:30:00-03:00')
    expect(lisbon).to include('2026-10-25T00:30:00+01:00')
  end

  it 'uses daylight saving offsets from the IANA timezone database' do
    summer = described_class.message('Europe/Lisbon', now: Time.utc(2026, 7, 1, 12))
    winter = described_class.message('Europe/Lisbon', now: Time.utc(2026, 1, 1, 12))

    expect(summer).to include('2026-07-01T13:00:00+01:00')
    expect(winter).to include('2026-01-01T12:00:00+00:00')
  end

  it 'keeps one refreshed time reference through tool continuations' do
    messages = [
      { role: 'system', content: 'Prompt' },
      { role: 'system', content: described_class.message('America/Sao_Paulo', now: instant) },
      { role: 'user', content: 'Question' },
      { 'role' => 'tool', 'content' => 'Result' }
    ]

    described_class.refresh!(messages, 'Europe/Lisbon', now: instant + 1.hour)

    time_messages = messages.select do |entry|
      entry[:content].to_s.start_with?('Data e hora atuais:') || entry['content'].to_s.start_with?('Data e hora atuais:')
    end
    expect(time_messages.length).to eq(1)
    expect(time_messages.first[:content]).to include('2026-10-25T01:30:00+01:00')
  end

  it 'renders the legacy prompt date expression before sending it' do
    prompt = 'Hoje é {{"now" | date: "%Y-%m-%d"}}.'

    expect(described_class.render_legacy_now(prompt, 'America/Sao_Paulo', now: instant)).to eq('Hoje é 2026-10-24.')
  end
end
