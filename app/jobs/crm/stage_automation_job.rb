class Crm::StageAutomationJob < ApplicationJob
  queue_as :default

  def perform(deal_id, stage_id, depth = 0)
    deal = Crm::Deal.find_by(id: deal_id)
    # A later move supersedes this one.
    return unless deal && deal.pipeline_stage_id == stage_id

    Crm::StageAutomationService.new(deal, depth: depth).perform
  end
end
