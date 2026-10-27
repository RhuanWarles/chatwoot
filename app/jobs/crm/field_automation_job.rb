class Crm::FieldAutomationJob < ApplicationJob
  queue_as :default

  def perform(deal_id, custom_field_id, depth = 0)
    deal = Crm::Deal.find_by(id: deal_id)
    return unless deal && deal.pipeline.field_automations.present?

    Crm::StageAutomationService.new(deal, depth: depth, trigger: 'field', field_id: custom_field_id).perform
  end
end
