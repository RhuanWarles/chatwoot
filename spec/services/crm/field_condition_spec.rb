require 'rails_helper'

RSpec.describe Crm::FieldCondition do
  def met?(operator, expected, actual)
    described_class.new(operator, expected).met?(actual)
  end

  describe '#met?' do
    it 'compares text ignoring case and surrounding spaces' do
      expect(met?('equals', 'restaurante', ' Restaurante ')).to be(true)
      expect(met?('equals', 'restaurante', 'Clínica')).to be(false)
      expect(met?('not_equals', 'restaurante', 'Clínica')).to be(true)
    end

    it 'matches any item of a multiselect value' do
      expect(met?('equals', 'a', %w[A B])).to be(true)
      expect(met?('equals', 'c', %w[A B])).to be(false)
      expect(met?('contains', 'cl', ['Clínica'])).to be(true)
    end

    it 'finds a fragment inside text' do
      expect(met?('contains', 'zza', 'Pizzaria do Zé')).to be(true)
      expect(met?('contains', 'sushi', 'Pizzaria do Zé')).to be(false)
    end

    it 'compares numbers numerically' do
      expect(met?('equals', '5', 5.0)).to be(true)
      expect(met?('gt', '10', 15.0)).to be(true)
      expect(met?('gt', '10', 9.0)).to be(false)
      expect(met?('lt', '10', 9.0)).to be(true)
    end

    it 'compares ISO dates' do
      expect(met?('gt', '2026-01-01', '2026-02-01')).to be(true)
      expect(met?('lt', '2026-01-01', '2026-02-01')).to be(false)
    end

    it 'never orders values that are not comparable' do
      expect(met?('gt', '10', 'abc')).to be(false)
      expect(met?('lt', '10', nil)).to be(false)
    end

    it 'tells filled from empty values' do
      [nil, '', '  ', []].each do |blank|
        expect(met?('filled', nil, blank)).to be(false)
        expect(met?('empty', nil, blank)).to be(true)
      end
      ['x', 0.0, false, ['a']].each do |present|
        expect(met?('filled', nil, present)).to be(true)
      end
    end

    it 'does not match an unknown operator' do
      expect(met?('between', '1', '1')).to be(false)
    end
  end

  describe '.valid_rule?' do
    let(:account) { create(:account) }
    let(:field) { account.crm_custom_fields.create!(name: 'Segmento', key: 'segmento', field_type: 'text') }

    it 'accepts known operators with a value, or valueless ones without it' do
      expect(described_class.valid_rule?(account, field.id, 'equals', 'Restaurante')).to be(true)
      expect(described_class.valid_rule?(account, field.id, 'filled', nil)).to be(true)
    end

    it 'rejects unknown operators, blank values and fields of other accounts' do
      other_field = create(:account).crm_custom_fields.create!(name: 'Outro', key: 'outro', field_type: 'text')

      expect(described_class.valid_rule?(account, field.id, 'between', 'x')).to be(false)
      expect(described_class.valid_rule?(account, field.id, 'equals', ' ')).to be(false)
      expect(described_class.valid_rule?(account, field.id, 'equals', 'a' * 256)).to be(false)
      expect(described_class.valid_rule?(account, other_field.id, 'equals', 'x')).to be(false)
      expect(described_class.valid_rule?(account, 'abc', 'equals', 'x')).to be(false)
    end

    it 'only accepts numbers or dates for ordering operators' do
      expect(described_class.valid_rule?(account, field.id, 'gt', '10')).to be(true)
      expect(described_class.valid_rule?(account, field.id, 'lt', '2026-01-01')).to be(true)
      expect(described_class.valid_rule?(account, field.id, 'gt', 'muito')).to be(false)
    end
  end
end
