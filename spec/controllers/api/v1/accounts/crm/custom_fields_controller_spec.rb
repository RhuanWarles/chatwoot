require 'rails_helper'

RSpec.describe 'Crm custom fields API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/crm/custom_fields" }
  let!(:first) { account.crm_custom_fields.create!(name: 'Primeiro', key: 'primeiro', field_type: 'text') }
  let!(:second) { account.crm_custom_fields.create!(name: 'Segundo', key: 'segundo', field_type: 'text') }
  let!(:third) { account.crm_custom_fields.create!(name: 'Terceiro', key: 'terceiro', field_type: 'text') }

  def reorder(ids)
    patch "#{base_url}/reorder", headers: agent.create_new_auth_token, params: { field_ids: ids }, as: :json
  end

  describe 'POST /crm/custom_fields' do
    it 'puts a new field at the end of the list' do
      first.update!(position: 4)

      post base_url, headers: agent.create_new_auth_token, params: { custom_field: { name: 'Novo', field_type: 'text' } }, as: :json

      expect(response).to have_http_status(:created)
      expect(account.crm_custom_fields.find_by(key: 'novo').position).to eq(5)
    end

    it 'keeps a position that was asked for' do
      post base_url, headers: agent.create_new_auth_token, params: { custom_field: { name: 'Fixo', field_type: 'text', position: 2 } }, as: :json

      expect(account.crm_custom_fields.find_by(key: 'fixo').position).to eq(2)
    end
  end

  describe 'PATCH /crm/custom_fields/reorder' do
    it 'saves the new order and lists the fields in it' do
      reorder([third.id, first.id, second.id])

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([third.id, first.id, second.id])

      get base_url, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body.pluck('key')).to eq(%w[terceiro primeiro segundo])
    end

    it 'turns the positions of fields that all sat at zero into 0, 1, 2' do
      reorder([second.id, third.id, first.id])

      expect([second, third, first].map { |field| field.reload.position }).to eq([0, 1, 2])
    end

    it 'needs every field exactly once' do
      reorder([first.id, second.id])
      expect(response).to have_http_status(:unprocessable_entity)

      reorder([first.id, first.id, second.id, third.id])
      expect(response).to have_http_status(:unprocessable_entity)

      expect(account.crm_custom_fields.order(:position, :id).pluck(:id)).to eq([first.id, second.id, third.id])
    end

    it 'refuses fields of another account and values that are not ids' do
      foreign = create(:account).crm_custom_fields.create!(name: 'Alheio', key: 'alheio', field_type: 'text')

      reorder([first.id, second.id, foreign.id])
      expect(response).to have_http_status(:unprocessable_entity)

      reorder(%w[a b c])
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'does not touch the fields of other accounts' do
      other_account = create(:account)
      foreign = other_account.crm_custom_fields.create!(name: 'Alheio', key: 'alheio', field_type: 'text', position: 9)

      reorder([second.id, first.id, third.id])

      expect(foreign.reload.position).to eq(9)
    end

    it 'needs a signed in user' do
      patch "#{base_url}/reorder", params: { field_ids: [first.id] }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
