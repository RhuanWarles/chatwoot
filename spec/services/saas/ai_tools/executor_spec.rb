require 'rails_helper'

RSpec.describe Saas::AiTools::Executor do
  Response = Struct.new(:code, :body)

  subject(:normalize) { described_class.allocate.send(:normalize_response, response) }

  let(:response) { Response.new(status, body) }
  let(:status) { 200 }
  let(:body) { '{"success":true,"result":"OK","internal_id":42}' }

  it 'accepts a successful fixed response contract' do
    expect(normalize).to include(valid: true, result: 'OK')
  end

  it 'accepts any 2xx status with a valid contract' do
    [201, 202].each do |code|
      expect(described_class.allocate.send(:normalize_response, Response.new(code, '{"success":true,"result":"Created"}'))).to include(valid: true)
    end
  end

  it 'rejects a 204 response without a body' do
    result = described_class.allocate.send(:normalize_response, Response.new(204, ''))

    expect(result).to include(valid: false, error_code: 'invalid_tool_response')
  end

  it 'rejects success false, missing fields, invalid JSON and empty results' do
    cases = {
      '{"success":false,"result":"Failed"}' => 'success_false',
      '{"result":"OK"}' => 'success_field_missing',
      '{"success":true}' => 'result_field_missing',
      '{"success":true,"result":""}' => 'result_invalid',
      'plain text' => 'invalid_tool_response'
    }

    cases.each do |payload, error_code|
      result = described_class.allocate.send(:normalize_response, Response.new(200, payload))
      expect(result).to include(valid: false, error_code: error_code)
    end
  end

  it 'rejects non-2xx responses without treating their body as a success contract' do
    result = described_class.allocate.send(:normalize_response, Response.new(404, '{"error":"Not found"}'))

    expect(result).to include(valid: false, error_code: 'http_error', error: 'Not found')
  end

  describe '#validate_uri!' do
    subject(:validate_uri) { described_class.allocate.send(:validate_uri!, uri) }

    let(:uri) { 'http://10.10.100.40:5678/webhook/pitchyes/consultar-conta' }

    it 'accepts a private endpoint when the URL is valid' do
      expect { validate_uri }.not_to raise_error
    end
  end
end
