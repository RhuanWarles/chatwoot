require 'rails_helper'

RSpec.describe Conversations::ViewPreferences do
  let(:preferences) do
    {
      'tabs' => { 'me' => true, 'unassigned' => true, 'all' => true, 'unanswered' => true },
      'filters' => { 'assistant' => true, 'inbox' => true, 'tag' => true, 'ai' => true }
    }
  end

  it 'accepts the complete preference shape' do
    result = described_class.validate(preferences)

    expect(result[:valid]).to be(true)
  end

  it 'accepts an unset preference' do
    expect(described_class.validate(nil)[:valid]).to be(true)
  end

  it 'rejects preferences that hide every tab' do
    preferences['tabs'].transform_values! { false }

    result = described_class.validate(preferences)

    expect(result).to eq(valid: false, field: 'tabs')
  end

  it 'rejects preferences that hide every filter' do
    preferences['filters'].transform_values! { false }

    result = described_class.validate(preferences)

    expect(result).to eq(valid: false, field: 'filters')
  end

  it 'rejects non-boolean values' do
    preferences['tabs']['all'] = 'true'

    result = described_class.validate(preferences)

    expect(result).to eq(valid: false, field: 'tabs')
  end
end
