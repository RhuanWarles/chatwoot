require 'rails_helper'

RSpec.describe Saas::AiTools::ParameterResolver do
  let(:account) { instance_double(Account, id: 1) }
  let(:agent) { instance_double(Saas::AiAgent, id: 2) }
  let(:contact) { instance_double(Contact, id: 3, phone_number: '+55 (62) 99999-9999', name: 'Rhuan', email: 'rhuan@example.com') }
  let(:conversation) { instance_double(Conversation, id: 4, contact: contact) }
  let(:tool) { instance_double(Saas::AiTool, parameters: parameters) }
  let(:resolver) { described_class.new(tool: tool, account: account, agent: agent, conversation: conversation) }

  let(:parameters) do
    [
      { 'name' => 'pedido_id', 'value_source' => 'ai', 'required' => true },
      { 'name' => 'telefone', 'value_source' => 'contact_phone', 'required' => true },
      { 'name' => 'conversa', 'value_source' => 'conversation_id', 'required' => false }
    ]
  end

  it 'combines AI arguments and contextual values' do
    expect(resolver.call('pedido_id' => '4382')).to eq(
      'pedido_id' => '4382', 'telefone' => '5562999999999', 'conversa' => 4
    )
  end

  it 'never accepts an argument for an internal source' do
    expect(resolver.call('pedido_id' => '4382', 'telefone' => '000')).to include('telefone' => '5562999999999')
  end

  it 'omits an optional internal value that is unavailable' do
    allow(contact).to receive(:email).and_return(nil)
    allow(tool).to receive(:parameters).and_return([{ 'name' => 'email', 'value_source' => 'contact_email', 'required' => false }])

    expect(resolver.call).to eq({})
  end

  it 'fails when a required internal value is unavailable' do
    allow(contact).to receive(:phone_number).and_return(nil)

    expect { resolver.call('pedido_id' => '4382') }.to raise_error(CustomExceptions::SaasError, 'missing_context_value:telefone')
  end
end
