require 'rails_helper'

RSpec.describe Workflows::Condition do
  describe '.met?' do
    it 'compares text ignoring case and numbers numerically' do
      expect(described_class.met?('Sem Orçamento', 'equals', 'sem orçamento')).to be(true)
      expect(described_class.met?(1500, 'equals', '1500.0')).to be(true)
      expect(described_class.met?(12, 'not_equals', '12')).to be(false)
    end

    it 'compares ids as strings' do
      expect(described_class.met?(7, 'equals', '7')).to be(true)
      expect(described_class.met?(7, 'in', %w[3 7])).to be(true)
      expect(described_class.met?(7, 'not_in', %w[3 7])).to be(false)
    end

    it 'treats a list as holding the value' do
      expect(described_class.met?(%w[vip novo], 'contains', 'vip')).to be(true)
      expect(described_class.met?(%w[vip novo], 'not_contains', 'frio')).to be(true)
    end

    it 'supports text and ordering operators' do
      expect(described_class.met?('Maria Silva', 'starts_with', 'maria')).to be(true)
      expect(described_class.met?('maria@x.com', 'ends_with', '@X.com')).to be(true)
      expect(described_class.met?(10, 'gt', 9)).to be(true)
      expect(described_class.met?(10, 'lte', 9)).to be(false)
      expect(described_class.met?('abc', 'gt', 1)).to be(false)
    end

    it 'checks presence' do
      expect(described_class.met?(nil, 'is_blank', nil)).to be(true)
      expect(described_class.met?('x', 'is_present', nil)).to be(true)
    end

    it 'never matches an unknown operator' do
      expect(described_class.met?('a', 'sounds_like', 'a')).to be(false)
    end
  end
end
