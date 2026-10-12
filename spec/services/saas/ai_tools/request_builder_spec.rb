require 'rails_helper'

RSpec.describe Saas::AiTools::RequestBuilder do
  let(:account) { instance_double(Account, id: 1) }
  let(:agent) { instance_double(Saas::AiAgent, id: 2) }
  let(:contact) { instance_double(Contact, id: 3, phone_number: '+55 (62) 99999-9999', name: 'Rhuan', email: 'rhuan@example.com') }
  let(:conversation) { instance_double(Conversation, id: 4, contact: contact) }
  let(:tool) { instance_double(Saas::AiTool, configuration: configuration, secret_headers: nil) }
  let(:configuration) { { 'method' => 'POST', 'url' => 'https://example.test/hooks', 'headers' => {}, 'query_params' => {}, 'body' => {} } }
  let(:builder) { described_class.new(tool: tool, account: account, agent: agent, conversation: conversation) }

  it 'uses arguments as an automatic JSON body for write requests' do
    request, = builder.build('name' => 'Rhuan', 'active' => true, 'quantity' => 2)

    expect(request.body).to eq('{"name":"Rhuan","active":true,"quantity":2}')
    expect(request['Content-Type']).to eq('application/json')
  end

  it 'sends public headers from the tool configuration' do
    tool_configuration = configuration.merge('headers' => { 'X-Webhook-Token' => 'public-token' })
    allow(tool).to receive(:configuration).and_return(tool_configuration)

    request, = builder.build({})

    expect(request['X-Webhook-Token']).to eq('public-token')
  end

  it 'sends encrypted secret headers without exposing them in configuration' do
    allow(tool).to receive(:secret_headers).and_return('{"Authorization":"Bearer test-token"}')

    request, = builder.build({})

    expect(request['Authorization']).to eq('Bearer test-token')
  end

  it 'uses arguments as query parameters for GET requests' do
    tool_configuration = configuration.merge('method' => 'GET')
    allow(tool).to receive(:configuration).and_return(tool_configuration)

    request, = builder.build('order_id' => '4382')

    expect(request.path).to eq('/hooks?order_id=4382')
    expect(request.body).to be_nil
  end

  it 'renders custom bodies and internal context variables' do
    tool_configuration = configuration.merge('body' => { 'phone' => '{{contact_phone}}', 'cpf' => '{{cpf}}', 'conversation' => '{{conversation_id}}' })
    allow(tool).to receive(:configuration).and_return(tool_configuration)

    request, = builder.build('cpf' => '123')

    expect(JSON.parse(request.body)).to eq('phone' => '5562999999999', 'cpf' => '123', 'conversation' => '4')
  end

  it 'does not call an external endpoint when a required context value is missing' do
    allow(contact).to receive(:phone_number).and_return(nil)
    tool_configuration = configuration.merge('body' => { 'phone' => '{{contact_phone}}' })
    allow(tool).to receive(:configuration).and_return(tool_configuration)

    expect { builder.build({}) }.to raise_error(CustomExceptions::SaasError, 'missing_context_variable:contact_phone')
  end
end
