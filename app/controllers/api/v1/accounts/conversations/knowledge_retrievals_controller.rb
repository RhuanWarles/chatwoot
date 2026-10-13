class Api::V1::Accounts::Conversations::KnowledgeRetrievalsController < Api::V1::Accounts::Conversations::BaseController
  include SaasAiAccess

  before_action -> { require_ai_feature('text') }

  def index
    records = Current.account.saas_usage_records.where(conversation_id: @conversation.id, source: 'knowledge_retrieval')
                             .order(created_at: :asc, id: :asc)
    render json: { retrievals: records.map { |record| retrieval_data(record) } }
  end

  def show
    record = Current.account.saas_usage_records.where(conversation_id: @conversation.id, source: 'knowledge_retrieval').find(params[:id])
    render json: { retrieval: retrieval_data(record, detailed: true) }
  end

  private

  def retrieval_data(record, detailed: false)
    details = record.metadata.fetch('retrieval', {})
    data = {
      id: record.id,
      created_at: record.created_at,
      agent: { id: record.metadata['ai_agent_id'], name: record.account.saas_ai_agents.find_by(id: record.metadata['ai_agent_id'])&.name },
      conversation_id: record.conversation_id,
      incoming_message_id: record.incoming_message_id,
      query: details['query'],
      knowledge_bases: details['bases'] || [],
      candidate_count: details['candidate_count'].to_i,
      accepted_count: details['accepted_count'].to_i,
      top_k: details['top_k'].to_i,
      threshold: details['threshold'].to_f,
      duration_ms: details['duration_ms'].to_i
    }
    data[:chunks] = details['chunks'] || [] if detailed
    data
  end
end
