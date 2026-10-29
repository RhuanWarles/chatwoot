class Workflows::TriggerService
  # A workflow that was itself set off by automations is allowed to run this many times for the same record
  # inside the window, which stops two workflows from handing the same deal back and forth forever.
  CHAIN_LIMIT = 10
  CHAIN_WINDOW = 5.minutes
  ENTITY_KEYS = %w[deal_id contact_id conversation_id].freeze

  class << self
    # Event driven: starts every active workflow that has a trigger for the event.
    def fire(account:, event:, context:, performed_by: nil)
      account.automation_workflows.active.where('trigger_events @> ARRAY[?]::varchar[]', event).find_each do |workflow|
        start(workflow, event, context) unless blocked?(workflow, context, performed_by)
      end
    end

    # Starts one workflow. A manual (test) run starts from every trigger node, whatever its event.
    def start(workflow, event, context)
      seeds = workflow.graph_model.triggers(event == 'manual' ? nil : event)
      return if seeds.empty?

      run = workflow.runs.create!(
        account_id: workflow.account_id, trigger_event: event, started_at: Time.current,
        context: context.stringify_keys, pending: seeds.map { |node| { 'node_id' => node[:id] } }
      )
      Workflows::RunJob.perform_later(run.id)
      run
    end

    private

    # An event the workflow caused itself never starts it again. Events caused by any automation (the pipeline automation jobs
    # report only their depth) stop at the pipeline automations' depth limit and count against the chain limit.
    def blocked?(workflow, context, performed_by)
      context = context.stringify_keys
      return true if context['automation_depth'].to_i >= Crm::StageAutomationService::MAX_DEPTH
      return true if performed_by.is_a?(AutomationWorkflow) && performed_by.id == workflow.id
      return false if performed_by.blank? && context['automation_depth'].to_i.zero?

      chained_too_often?(workflow, context)
    end

    def chained_too_often?(workflow, context)
      key = ENTITY_KEYS.find { |item| context[item].present? }
      return false unless key

      workflow.runs.where(created_at: CHAIN_WINDOW.ago..).where('context ->> ? = ?', key, context[key].to_s).count >= CHAIN_LIMIT
    end
  end
end
