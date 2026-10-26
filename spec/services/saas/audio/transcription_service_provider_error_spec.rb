require 'rails_helper'

RSpec.describe Saas::Audio::TranscriptionService, type: :service do
  it 'extracts the provider error fields without logging the response wholesale' do
    error = Faraday::BadRequestError.new(
      'bad request',
      status: 400,
      body: {
        'error' => {
          'type' => 'invalid_request_error', 'code' => 'unsupported_value', 'param' => 'file',
          'message' => 'Unsupported file format oga'
        },
        'request_id' => 'req-test'
      }
    )

    details = described_class.allocate.send(:provider_error_details, error)

    expect(details).to eq(
      http_status: 400, type: 'invalid_request_error', code: 'unsupported_value', param: 'file',
      message: 'Unsupported file format oga'
    )
    expect(details.to_json).not_to include('req-test')
  end
end
