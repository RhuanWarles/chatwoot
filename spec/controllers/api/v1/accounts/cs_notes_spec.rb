require 'rails_helper'

RSpec.describe 'CS notes of a contact', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:cs_agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:cs_team) { create(:team, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}" }

  before do
    create(:team_member, team: cs_team, user: cs_agent)
    account.update!(cs_team_id: cs_team.id)
  end

  def headers_for(user)
    user.create_new_auth_token
  end

  def create_field(name: 'Próximo contato', type: 'text', **extra)
    post "#{base_url}/cs_note_fields", headers: headers_for(admin), as: :json,
                                       params: { cs_note_field: { attribute_display_name: name, attribute_display_type: type, **extra } }
    response.parsed_body
  end

  describe 'GET /cs_note_settings' do
    it 'gives an administrator the fields, the team and the right to manage' do
      create_field

      get "#{base_url}/cs_note_settings", headers: headers_for(admin), as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('can_access' => true, 'can_manage' => true, 'team_id' => cs_team.id)
      expect(response.parsed_body['fields'].pluck('attribute_key')).to eq(['proximo_contato'])
    end

    it 'gives a member of the team the fields, but not the right to choose the team' do
      create_field

      get "#{base_url}/cs_note_settings", headers: headers_for(cs_agent), as: :json

      expect(response.parsed_body).to include('can_access' => true, 'can_manage' => false)
      expect(response.parsed_body['fields']).to be_present
      expect(response.parsed_body).not_to have_key('team_id')
    end

    it 'tells any other agent there is nothing for them, without the fields' do
      create_field

      get "#{base_url}/cs_note_settings", headers: headers_for(other_agent), as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq('can_access' => false, 'can_manage' => false)
    end

    it 'keeps everyone but the administrators out while no team was chosen' do
      account.update!(cs_team_id: nil)

      get "#{base_url}/cs_note_settings", headers: headers_for(cs_agent), as: :json

      expect(response.parsed_body['can_access']).to be(false)
    end
  end

  describe 'PATCH /cs_note_settings' do
    it 'lets an administrator choose the team' do
      other_team = create(:team, account: account)

      patch "#{base_url}/cs_note_settings", headers: headers_for(admin), params: { team_id: other_team.id }, as: :json

      expect(response).to have_http_status(:success)
      expect(account.reload.cs_team_id.to_i).to eq(other_team.id)
      expect(response.parsed_body['team_id']).to eq(other_team.id)
    end

    it 'lets an administrator turn the team off' do
      patch "#{base_url}/cs_note_settings", headers: headers_for(admin), params: { team_id: nil }, as: :json

      expect(account.reload.cs_team_id).to be_nil
    end

    it 'does not accept a team of another account' do
      foreign_team = create(:team)

      patch "#{base_url}/cs_note_settings", headers: headers_for(admin), params: { team_id: foreign_team.id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(account.reload.cs_team_id.to_i).to eq(cs_team.id)
    end

    it 'is not allowed for the team itself' do
      patch "#{base_url}/cs_note_settings", headers: headers_for(cs_agent), params: { team_id: nil }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(account.reload.cs_team_id.to_i).to eq(cs_team.id)
    end
  end

  describe 'fields' do
    it 'are created by the team in charge, with a key made from the name' do
      post "#{base_url}/cs_note_fields", headers: headers_for(cs_agent), as: :json,
                                         params: { cs_note_field: { attribute_display_name: 'Nível de Saúde', attribute_display_type: 'text' } }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('attribute_key' => 'nivel_de_saude', 'attribute_model' => 'cs_attribute')
    end

    it 'give a number to a name that is taken already' do
      create_field(name: 'Plano')
      create_field(name: 'Plano')

      expect(account.custom_attribute_definitions.cs_attribute.pluck(:attribute_key)).to contain_exactly('plano', 'plano_2')
    end

    it 'keep the options of a list' do
      field = create_field(name: 'Risco', type: 'list', attribute_values: %w[Baixo Alto])

      expect(field['attribute_values']).to eq(%w[Baixo Alto])
    end

    it 'are closed to the other agents' do
      post "#{base_url}/cs_note_fields", headers: headers_for(other_agent), as: :json,
                                         params: { cs_note_field: { attribute_display_name: 'Plano', attribute_display_type: 'text' } }

      expect(response).to have_http_status(:unauthorized)
      expect(account.custom_attribute_definitions.cs_attribute).to be_empty
    end

    it 'can be renamed, but keep their key and type' do
      field = create_field(name: 'Plano')

      patch "#{base_url}/cs_note_fields/#{field['id']}", headers: headers_for(cs_agent), as: :json,
                                                          params: { cs_note_field: { attribute_display_name: 'Plano atual',
                                                                                     attribute_display_type: 'number',
                                                                                     attribute_key: 'outro' } }

      expect(response.parsed_body).to include('attribute_display_name' => 'Plano atual', 'attribute_key' => 'plano',
                                              'attribute_display_type' => 'text')
    end

    it 'take their values away from the contacts when deleted' do
      field = create_field(name: 'Plano')
      create(:contact_cs_note, account: account, contact: contact, field_values: { 'plano' => 'Pro', 'outro' => 'x' })

      delete "#{base_url}/cs_note_fields/#{field['id']}", headers: headers_for(cs_agent), as: :json

      expect(response).to have_http_status(:no_content)
      expect(ContactCsNote.find_by(contact: contact).field_values).to eq('outro' => 'x')
    end

    it 'are not listed among the custom attributes of the account' do
      create_field(name: 'Plano')
      create(:custom_attribute_definition, account: account, attribute_model: :contact_attribute)

      get "#{base_url}/custom_attribute_definitions", headers: headers_for(other_agent), as: :json

      expect(response.parsed_body.pluck('attribute_model')).to eq(['contact_attribute'])
    end

    it 'cannot be created as a plain custom attribute' do
      post "#{base_url}/custom_attribute_definitions", headers: headers_for(admin), as: :json,
                                                       params: { custom_attribute_definition: { attribute_display_name: 'Plano',
                                                                                                attribute_key: 'plano',
                                                                                                attribute_display_type: 0,
                                                                                                attribute_model: 'cs_attribute' } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(account.custom_attribute_definitions.cs_attribute).to be_empty
    end
  end

  describe 'values of a contact' do
    let!(:plan) { create_field(name: 'Plano') }
    let!(:risk) { create_field(name: 'Risco', type: 'list', attribute_values: %w[Baixo Alto]) }
    let(:url) { "#{base_url}/contacts/#{contact.id}/cs_note" }

    def save(values, user: cs_agent)
      patch url, headers: headers_for(user), params: { field_values: values }, as: :json
    end

    it 'are written and read back by the team in charge' do
      save({ plano: 'Pro', risco: 'Alto' })

      expect(response).to have_http_status(:success)
      get url, headers: headers_for(admin), as: :json
      expect(response.parsed_body['field_values']).to eq('plano' => 'Pro', 'risco' => 'Alto')
    end

    it 'only change the fields that were sent' do
      save({ plano: 'Pro', risco: 'Alto' })

      save({ risco: 'Baixo' })

      expect(response.parsed_body['field_values']).to eq('plano' => 'Pro', 'risco' => 'Baixo')
    end

    it 'are cleared by an empty value' do
      save({ plano: 'Pro' })

      save({ plano: '' })

      expect(response.parsed_body['field_values']).to eq({})
    end

    it 'ignore a field that does not exist' do
      save({ inventado: 'x' })

      expect(response.parsed_body['field_values']).to eq({})
    end

    it 'ignore an option that is not in the list' do
      save({ risco: 'Altíssimo' })

      expect(response.parsed_body['field_values']).to eq({})
    end

    it 'ignore anything that is not plain text, number or yes/no' do
      save({ plano: { nested: 'x' } })

      expect(response.parsed_body['field_values']).to eq({})
    end

    it 'are closed to the other agents, to read and to write' do
      save({ plano: 'Pro' })

      get url, headers: headers_for(other_agent), as: :json
      expect(response).to have_http_status(:unauthorized)

      save({ plano: 'Hack' }, user: other_agent)
      expect(response).to have_http_status(:unauthorized)
      expect(ContactCsNote.find_by(contact: contact).field_values).to eq('plano' => 'Pro')
    end

    it 'never come with the contact' do
      save({ plano: 'ValorSecretoCS' })

      get "#{base_url}/contacts/#{contact.id}", headers: headers_for(other_agent), as: :json

      expect(response.body).not_to include('ValorSecretoCS')
      expect(contact.reload.as_json.to_s).not_to include('ValorSecretoCS')
    end

    it 'cannot be reached through a contact of another account' do
      foreign_contact = create(:contact)

      patch "#{base_url}/contacts/#{foreign_contact.id}/cs_note", headers: headers_for(admin), params: { field_values: { plano: 'x' } }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
