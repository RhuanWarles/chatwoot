# Tokens spent by the AI turns of a set of messages, in total and by model, so a cost can be estimated with the price of
# each model. A turn answered in several messages (split replies) shares one usage, so it is counted once.
class Saas::AiTokenUsage
  def initialize(messages)
    @turns = messages.pluck(:id, :content_attributes).uniq { |id, attributes| attributes['ai_response_batch_id'] || id }.map(&:last)
  end

  def perform
    { prompt_tokens: sum('prompt_tokens'), completion_tokens: sum('completion_tokens'), total_tokens: sum('total_tokens'),
      models: models }
  end

  private

  def sum(key, turns = @turns)
    turns.sum { |attributes| attributes['ai_token_usage'].to_h[key].to_i }
  end

  def models
    by_model = @turns.group_by { |attributes| [attributes['ai_provider'], attributes['ai_model']] }
    items = by_model.map do |(provider, model), turns|
      { provider: provider, model: model, responses: turns.length,
        prompt_tokens: sum('prompt_tokens', turns), completion_tokens: sum('completion_tokens', turns) }
    end
    items.sort_by { |item| -item[:responses] }
  end
end
