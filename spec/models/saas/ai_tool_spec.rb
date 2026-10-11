require 'rails_helper'

RSpec.describe Saas::AiTool do
  let(:account) { create(:account) }
  let(:tool) do
    account.saas_ai_tools.build(
      name: 'Consultar pedido', slug: 'consultar_pedido', description: 'Consulta um pedido', active: true,
      configuration: { 'method' => 'GET', 'url' => 'https://example.com/orders/{{pedido_id}}', 'timeout_seconds' => 10,
                       'parameters' => [{ 'name' => 'pedido_id', 'type' => 'string', 'required' => true }] }
    )
  end

  it 'builds a function schema without exposing request configuration' do
    expect(tool.function_definition).to include(type: 'function')
    expect(tool.function_definition.dig(:function, :parameters, 'required')).to eq(['pedido_id'])
    tool.secret_headers = '{"Authorization":"secret"}'
    expect(tool.public_data.dig('configuration', 'secret_headers')).to be_nil
  end

  it 'keeps tools isolated by account' do
    other = create(:account)
    expect(other.saas_ai_tools.where(id: tool.id)).to be_empty
  end
end
