# Where the cards that are created automatically for every new lead go. Stored in the account settings:
# { 'enabled' => true, 'pipeline_id' => nil, 'stage_id' => nil }. Without a pipeline the oldest active pipeline that has
# stages is used, and without a stage the first stage of the pipeline.
class Crm::AutoCardSettings
  class Invalid < StandardError; end

  def initialize(account)
    @account = account
  end

  def enabled?
    config.fetch('enabled', true)
  end

  def pipeline_id
    config['pipeline_id'].presence&.to_i
  end

  def stage_id
    config['stage_id'].presence&.to_i
  end

  def as_json(*)
    { enabled: enabled?, pipeline_id: pipeline_id, stage_id: stage_id }
  end

  def update!(enabled:, pipeline_id:, stage_id:)
    pipeline = pipeline_id.presence && @account.crm_pipelines.active.find_by(id: pipeline_id)
    raise Invalid, I18n.t('crm.auto_card.errors.pipeline') if pipeline_id.present? && pipeline.nil?
    raise Invalid, I18n.t('crm.auto_card.errors.stage') if stage_id.present? && !pipeline&.stages&.exists?(id: stage_id)

    enabled = true if enabled.nil?
    @account.update!(crm_auto_card: { 'enabled' => ActiveModel::Type::Boolean.new.cast(enabled), 'pipeline_id' => pipeline&.id,
                                      'stage_id' => stage_id.presence&.to_i })
  end

  # `preferred_pipeline_id` (the pipeline of the AI agent that answers the conversation) wins, so the agent finds the card.
  def target(preferred_pipeline_id: nil)
    pipeline = [preferred_pipeline_id, pipeline_id].compact.filter_map { |id| usable_pipeline(id) }.first || default_pipeline
    return unless pipeline

    stage = pipeline.stages.find_by(id: stage_id) if pipeline.id == pipeline_id
    [pipeline, stage || pipeline.stages.first]
  end

  private

  def config
    @account.crm_auto_card || {}
  end

  def usable_pipeline(id)
    @account.crm_pipelines.active.where(id: Crm::PipelineStage.select(:pipeline_id)).find_by(id: id)
  end

  def default_pipeline
    @account.crm_pipelines.active.where(id: Crm::PipelineStage.select(:pipeline_id)).order(:id).first
  end
end
