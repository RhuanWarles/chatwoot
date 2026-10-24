class Crm::OutcomeAutomationJob < ApplicationJob
  queue_as :default

  def perform(deal_id, status, depth = 0)
    deal = Crm::Deal.find_by(id: deal_id)
    # A later status change supersedes this one.
    return unless deal && deal.status == status

    Crm::StageAutomationService.new(deal, depth: depth, trigger: status).perform
  end
end
