class Saas::GenerateTextJob < ApplicationJob
  queue_as :default

  def perform(generation_id)
    generation = Saas::TextGeneration.find(generation_id)
    claimed = generation.with_lock do
      next false unless generation.status == 'pending'

      generation.update!(status: 'running')
      true
    end
    return unless claimed

    response = Saas::TextService.new(generation.account).generate(generation)
    complete_generation(generation, response)
  rescue RubyLLM::Error, Faraday::Error, CustomExceptions::SaasError
    Saas::TextGeneration.transaction do
      usage = generation.usage_record
      usage&.wallet&.release!(usage)
      generation.update!(status: 'failed', error_code: 'text_provider_error')
    end
  end

  private

  def complete_generation(generation, response)
    Saas::TextGeneration.transaction do
      usage = generation.usage_record
      usage&.wallet&.settle!(usage, units: usage.reserved_units)
      generation.update!(status: 'completed', response: response.content.to_s,
                         input_tokens: response.input_tokens, output_tokens: response.output_tokens)
    end
  end
end
