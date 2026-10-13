require 'rails_helper'

RSpec.describe Saas::AiAgents::MessageSplitter do
  it 'keeps short replies as one message' do
    expect(described_class.call('Tudo certo.', 3)).to eq(['Tudo certo.'])
  end

  it 'splits paragraphs without exceeding the configured maximum' do
    content = "Primeiro parágrafo com informação suficiente para uma resposta mais longa e legível.\n\nSegundo parágrafo com outra informação importante para o cliente.\n\nTerceiro parágrafo com a conclusão da resposta."
    chunks = described_class.call(content, 2)
    expect(chunks.length).to eq(2)
    expect(chunks.join).to include('Primeiro parágrafo', 'Terceiro parágrafo')
  end

  it 'does not split list items independently' do
    content = "Confira as opções:\n- Primeiro item\n- Segundo item\n- Terceiro item"
    expect(described_class.call(content, 3)).to eq([content])
  end
end
