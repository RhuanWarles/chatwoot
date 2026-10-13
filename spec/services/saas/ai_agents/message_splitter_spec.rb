require 'rails_helper'

RSpec.describe Saas::AiAgents::MessageSplitter do
  it 'keeps short replies as one message' do
    expect(described_class.call('Tudo certo.', true)).to eq(['Tudo certo.'])
  end

  it 'splits paragraphs while preserving list items in one block' do
    content = "Olá!\n\nComo posso ajudar hoje?"
    expect(described_class.call(content, true)).to eq(['Olá!', 'Como posso ajudar hoje?'])
  end

  it 'keeps list items together when there are no blank lines' do
    content = "Confira as opções:\n- Primeiro item\n- Segundo item\n- Terceiro item"
    expect(described_class.call(content, true)).to eq([content])
  end

  it 'keeps the complete response in one message when disabled' do
    content = "Primeiro parágrafo.\n\nSegundo parágrafo."
    expect(described_class.call(content, false)).to eq([content])
  end

  it 'removes empty paragraph blocks' do
    expect(described_class.call("Um.\n\n\nDois.", true)).to eq(['Um.', 'Dois.'])
  end

  it 'groups excess paragraphs into the final safeguard message' do
    content = (1..10).map { |index| "Parágrafo #{index}" }.join("\n\n")
    chunks = described_class.call(content, true)
    expect(chunks.length).to eq(8)
    expect(chunks.last).to include('Parágrafo 8', 'Parágrafo 10')
  end
end
