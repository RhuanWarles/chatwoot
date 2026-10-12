require 'rails_helper'

RSpec.describe Saas::Knowledge::Embeddings do
  let(:account) { create(:account) }
  let(:client) { instance_double(OpenAI::Client) }
  let(:vector) { [1.0] + Array.new(1535, 0.0) }

  it 'records internal tokens with zero wallet debit and keeps credentials private' do
    with_modified_env SAAS_EMBEDDING_PROVIDER: 'openai', SAAS_EMBEDDING_MODEL: 'text-embedding-3-small', SAAS_EMBEDDING_API_KEY: 'test-secret' do
      allow(OpenAI::Client).to receive(:new).and_return(client)
      allow(client).to receive(:embeddings).and_return('data' => [{ 'index' => 0, 'embedding' => vector }], 'usage' => { 'total_tokens' => 8 })
      wallet = Saas::Wallet.for_account(account, 'text_credits')
      wallet.credit!(units: 20, reference: 'embedding-spec-credit')
      expect(described_class.call(account: account, texts: ['Warranty'], source: 'knowledge_embedding', document_id: 123)).to eq([vector])
      record = Saas::UsageRecord.where(account: account, source: 'knowledge_embedding').last
      expect(record).to have_attributes(status: 'completed', units: 0, reserved_units: 0, total_tokens: 8)
      expect(record.metadata['knowledge_document_id']).to eq(123)
      expect(record.attributes.to_json).not_to include('test-secret')
      expect(wallet.reload.available_units).to eq(20)
    end
  end

  it 'records failures without exposing provider error details' do
    with_modified_env SAAS_EMBEDDING_PROVIDER: 'openai', SAAS_EMBEDDING_MODEL: 'text-embedding-3-small', SAAS_EMBEDDING_API_KEY: 'test-secret' do
      allow(OpenAI::Client).to receive(:new).and_return(client)
      allow(client).to receive(:embeddings).and_raise(StandardError, 'test-secret')
      expect { described_class.call(account: account, texts: ['Warranty'], source: 'knowledge_retrieval') }.to raise_error(CustomExceptions::SaasError, 'embedding_failed')
      expect(Saas::UsageRecord.where(account: account).last).to have_attributes(status: 'failed', error_code: 'embedding_failed')
    end
  end
end
