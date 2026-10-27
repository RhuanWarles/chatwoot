require 'rails_helper'

RSpec.describe 'AI analytics replies API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_analytics/replies" }

  before { account.enable_features!('text_ai') }

  it 'compares the AI with people month by month' do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                     content_attributes: { generated_by_ai: true })
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: admin)

    get url, params: { months: 3 }, headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    data = response.parsed_body
    expect(data['months'].length).to eq(3)
    expect(data['months'].last).to include('ai_replies' => 1, 'human_replies' => 1, 'ai_share' => 50.0)
    expect(data['totals']).to include('ai_replies' => 1, 'human_replies' => 1)
    expect(data['people'].pluck('id')).to include(admin.id)
  end

  it 'accepts the filters as lists' do
    segment = account.crm_segments.create!(name: 'Restaurantes')

    get url, params: { segment_ids: [segment.id], answered_by: ['ai', admin.id], owner_ids: ['none'] },
             headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['filters']).to include('segment_ids' => [segment.id.to_s], 'answered_by' => ['ai', admin.id.to_s])
  end

  it 'refuses invalid filters' do
    get url, params: { months: 99 }, headers: admin.create_new_auth_token

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'is reserved for administrators' do
    get url, headers: agent.create_new_auth_token

    expect(response).to have_http_status(:unauthorized)
  end

  it 'needs the AI feature on the account' do
    account.disable_features!('text_ai')

    get url, headers: admin.create_new_auth_token

    expect(response).not_to have_http_status(:ok)
  end
end
