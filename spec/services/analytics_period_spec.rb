require 'rails_helper'

RSpec.describe AnalyticsPeriod do
  let(:account) { create(:account) }

  def period(params = {})
    described_class.new(account, params)
  end

  # 01:30 UTC of the 12th is still 22:30 of the 11th in São Paulo.
  around { |example| travel_to(Time.utc(2026, 11, 12, 1, 30)) { example.run } }

  describe 'presets' do
    it 'reads the days in UTC when the account has no reporting time zone' do
      expect(period(period: 'today').range.begin).to eq(Time.utc(2026, 11, 12))
      expect(period(period: 'month').range.begin).to eq(Time.utc(2026, 11, 1))
    end

    it 'reads the days in the reporting time zone of the account' do
      account.update!(reporting_timezone: 'America/Sao_Paulo')

      expect(period(period: 'today').range.begin).to eq(Time.utc(2026, 11, 11, 3))
      expect(period(period: 'today').dates.map(&:to_s)).to eq(['2026-11-11'])
    end

    it 'makes the last 7 and 30 days start at midnight, so the first bar is a whole day' do
      expect(period(period: '7d').range.begin).to eq(Time.utc(2026, 11, 6))
      expect(period(period: '7d').dates.length).to eq(7)
      expect(period(period: '30d').dates.length).to eq(30)
      expect(period.range.begin).to eq(Time.utc(2026, 11, 6))
    end

    it 'exposes the zone, for the screen to say which days it is showing' do
      account.update!(reporting_timezone: 'America/Sao_Paulo')

      expect(period.zone.tzinfo.name).to eq('America/Sao_Paulo')
      expect(described_class.zone_for(create(:account)).tzinfo.name).to eq('Etc/UTC')
    end
  end

  describe 'custom periods' do
    it 'takes whole days of the account, from the start of the first to the end of the last' do
      account.update!(reporting_timezone: 'America/Sao_Paulo')
      range = period(start_date: '2026-11-01', end_date: '2026-11-05').range

      expect(range.begin).to eq(Time.utc(2026, 11, 1, 3))
      expect(range.end.to_i).to eq(Time.utc(2026, 11, 6, 2, 59, 59).to_i)
    end

    it 'still accepts exact moments' do
      range = period(start_at: '2026-11-01T10:00:00Z', end_at: '2026-11-02T10:00:00Z').range

      expect(range.begin).to eq(Time.utc(2026, 11, 1, 10))
      expect(range.end).to eq(Time.utc(2026, 11, 2, 10))
    end

    it 'rejects what is not a day, or an end before the start' do
      expect { period(start_date: 'ontem') }.to raise_error(ArgumentError, 'invalid_period')
      expect { period(start_date: '2026-11-05', end_date: '2026-11-01') }.to raise_error(ArgumentError, 'invalid_period')
      expect { period(start_at: 'x') }.to raise_error(ArgumentError, 'invalid_period')
    end
  end

  describe '#previous_range' do
    it 'is the same length, right before the period' do
      current = period(period: '7d')
      previous = current.previous_range

      expect(previous.end).to eq(current.range.begin)
      expect(previous.end - previous.begin).to be_within(1).of(current.range.end - current.range.begin)
      expect(previous.exclude_end?).to be(true)
    end
  end
end
