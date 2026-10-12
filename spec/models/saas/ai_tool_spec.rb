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

  it 'generates a stable snake case slug from the name on create' do
    generated = account.saas_ai_tools.create!(name: 'Consultar situação!', description: 'Consulta', configuration: {
      'method' => 'GET', 'url' => 'https://example.com', 'timeout_seconds' => 10
    })

    expect(generated.slug).to eq('consultar_situacao')
    generated.update!(name: 'Consultar pedido do cliente')
    expect(generated.reload.slug).to eq('consultar_situacao')
  end

  it 'keeps duplicate slugs scoped to the account' do
    account.saas_ai_tools.create!(name: 'Send Link', description: 'First', configuration: {
      'method' => 'GET', 'url' => 'https://example.com', 'timeout_seconds' => 10
    })
    duplicate = account.saas_ai_tools.build(name: 'Send-Link', description: 'Second', configuration: {
      'method' => 'GET', 'url' => 'https://example.com', 'timeout_seconds' => 10
    })
    other = create(:account).saas_ai_tools.create!(name: 'Send Link', description: 'Other', configuration: {
      'method' => 'GET', 'url' => 'https://example.com', 'timeout_seconds' => 10
    })

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:slug]).to include('has already been taken')
    expect(other.slug).to eq('send_link')
  end
end
