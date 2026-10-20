require 'rails_helper'

describe '/app/login', type: :request do
  context 'with optional WhatsApp connection management' do
    it 'exposes only a boolean when both provider settings are present' do
      with_modified_env EVOLUTION_API_URL: 'https://private-evolution.example.test', EVOLUTION_API_KEY: 'private-provider-api-key' do
        get '/app/login'
        expect(response).to have_http_status(:success)
        expect(response.body).to include('"WHATSAPP_CONNECTIONS_ENABLED":true')
        expect(response.body).not_to include('private-provider-api-key', 'private-evolution.example.test')
      end
    end

    it 'hides the feature without the provider URL' do
      with_modified_env EVOLUTION_API_URL: nil, EVOLUTION_API_KEY: 'private-provider-api-key' do
        get '/app/login'
        expect(response.body).to include('"WHATSAPP_CONNECTIONS_ENABLED":false')
        expect(response.body).not_to include('private-provider-api-key')
      end
    end

    it 'hides the feature without the provider key' do
      with_modified_env EVOLUTION_API_URL: 'https://private-evolution.example.test', EVOLUTION_API_KEY: nil do
        get '/app/login'
        expect(response.body).to include('"WHATSAPP_CONNECTIONS_ENABLED":false')
      end
    end
  end

  context 'without DEFAULT_LOCALE' do
    it 'renders the dashboard' do
      get '/app/login'
      expect(response).to have_http_status(:success)
    end
  end

  context 'with DEFAULT_LOCALE' do
    it 'renders the dashboard' do
      with_modified_env DEFAULT_LOCALE: 'pt_BR' do
        get '/app/login'
        expect(response).to have_http_status(:success)
        expect(response.body).to include "selectedLocale: 'pt_BR'"
      end
    end
  end

  context 'with non-HTML format' do
    it 'returns not acceptable for JSON with error message' do
      get '/app/login', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:not_acceptable)
      expect(response.parsed_body).to eq({ 'error' => 'Please use API routes instead of dashboard routes for JSON requests' })
    end
  end

  # Routes are loaded once on app start
  # hence Rails.application.reload_routes! is used in this spec
  # ref : https://stackoverflow.com/a/63584877/939299
  context 'with CW_API_ONLY_SERVER true' do
    it 'returns 404' do
      with_modified_env CW_API_ONLY_SERVER: 'true' do
        Rails.application.reload_routes!
        get '/app/login'
        expect(response).to have_http_status(:not_found)
      end
      Rails.application.reload_routes!
    end
  end
end
