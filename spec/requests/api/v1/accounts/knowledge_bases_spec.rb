require 'rails_helper'

RSpec.describe 'Knowledge API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:url) { "/api/v1/accounts/#{account.id}/knowledge_bases" }
  let(:base) { account.saas_knowledge_bases.create!(name: 'FAQ') }

  before do
    account.enable_features!('text_ai')
    ActiveJob::Base.queue_adapter = :test
  end

  it 'creates, updates, lists and removes a base without accepting account ownership' do
    post url, params: { knowledge_base: { name: 'FAQ', active: true } }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    id = response.parsed_body['id']
    patch "#{url}/#{id}", params: { knowledge_base: { name: 'Warranty' } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    get url, headers: headers
    expect(response.parsed_body['bases'].first['name']).to eq('Warranty')
    post url, params: { knowledge_base: { name: 'Bad', account_id: 999 } }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    delete "#{url}/#{id}", headers: headers
    expect(response).to have_http_status(:no_content)
  end

  it 'persists retrieval and chunking settings with safe defaults' do
    post url, params: { knowledge_base: { name: 'Configured', similarity_threshold: 0.42, retrieval_top_k: 7,
                                          chunk_size: 1800, chunk_overlap: 180 } }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('similarity_threshold' => '0.42', 'retrieval_top_k' => 7,
                                             'chunk_size' => 1800, 'chunk_overlap' => 180)
    post url, params: { knowledge_base: { name: 'Invalid', chunk_size: 400, chunk_overlap: 400 } },
         headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'denies foreign bases and foreign agent assignments' do
    foreign = create(:account).saas_knowledge_bases.create!(name: 'Private')
    get "#{url}/#{foreign.id}", headers: headers
    expect(response).to have_http_status(:not_found)
    agent = account.saas_ai_agents.create!(name: 'Agent', provider: 'openai', model: 'gpt-4.1', system_prompt: 'Help')
    patch "/api/v1/accounts/#{account.id}/ai_agents/#{agent.id}", params: { ai_agent: { knowledge_base_ids: [foreign.id] } }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(agent.reload.knowledge_bases).to be_empty
  end

  it 'rejects non-admin users and oversized manual text' do
    user = create(:user, account: account, role: :agent)
    post url, params: { knowledge_base: { name: 'FAQ' } }, headers: user.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    post "#{url}/#{base.id}/documents", params: { document: { name: 'Large', content: 'a' * 500_001 } }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(base.documents).to be_empty
  end

  it 'queues manual text, validates uploads and exposes no vectors' do
    post "#{url}/#{base.id}/documents", params: { document: { name: 'Policy', content: '12 months' } }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['status']).to eq('processing')
    id = response.parsed_body['id']
    get "#{url}/#{base.id}/documents/#{id}", headers: headers
    expect(response.parsed_body['content']).to eq('12 months')
    expect(response.parsed_body).not_to have_key('embedding')
    upload = Rack::Test::UploadedFile.new(StringIO.new('Warranty 12 months'), 'text/plain', original_filename: 'policy.txt')
    post "#{url}/#{base.id}/documents", params: { document: { name: 'File', file: upload } }, headers: headers
    expect(response).to have_http_status(:created)
    invalid = Rack::Test::UploadedFile.new(StringIO.new('executable'), 'application/octet-stream', original_filename: 'bad.exe')
    post "#{url}/#{base.id}/documents", params: { document: { name: 'Bad', file: invalid } }, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
