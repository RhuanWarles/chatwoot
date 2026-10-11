class Saas::AiPricing
  TOKEN_SCALE = 1_000_000.to_d

  def self.quote(provider:, model:, usage:)
    rates = Rails.application.config_for(:ai_pricing).dig(provider.to_s, model.to_s)
    return { estimated_cost_usd: nil, snapshot: {} } unless rates

    prompt_tokens = usage.fetch('prompt_tokens', 0).to_i
    cached_tokens = [usage.fetch('cached_tokens', 0).to_i, prompt_tokens].min
    completion_tokens = usage.fetch('completion_tokens', 0).to_i
    uncached_tokens = prompt_tokens - cached_tokens
    cost = (uncached_tokens * rates.fetch('input_per_million_usd').to_d +
            cached_tokens * rates.fetch('cached_input_per_million_usd', rates.fetch('input_per_million_usd')).to_d +
            completion_tokens * rates.fetch('output_per_million_usd').to_d) / TOKEN_SCALE

    { estimated_cost_usd: cost.round(10), snapshot: rates.merge('provider' => provider.to_s, 'model' => model.to_s) }
  end
end
