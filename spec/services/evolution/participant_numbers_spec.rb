require 'rails_helper'

RSpec.describe Evolution::ParticipantNumbers do
  it 'keeps existing group management normalization and deduplication' do
    expect(described_class.normalize(['+55 (62) 99999-1111', '5562999991111'])).to eq(['5562999991111'])
  end

  it 'preserves the existing minimum length and nonempty list requirements for group management' do
    [[], ['+290 1234'], nil, ['invalid']].each do |value|
      expect { described_class.normalize(value) }.to(raise_error { |error| expect(error.class.name).to eq('CustomExceptions::Evolution') })
    end
  end

  it 'allows shorter international numbers when the caller explicitly requests them' do
    expect(described_class.normalize_phone('+290 1234', minimum_digits: 7)).to eq('2901234')
  end

  it 'canonicalizes Brazilian mobile numbers with or without the ninth digit' do
    expect(described_class.normalize_phone('55 62 91212-010')).to eq('5562991212010')
    expect(described_class.normalize_phone('55 62 9 91212-010')).to eq('5562991212010')
    expect(described_class.normalize_phone('55 62 3212-0101')).to eq('556232120101')
  end
end
