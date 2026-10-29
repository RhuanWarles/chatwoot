require 'rails_helper'

RSpec.describe AutomationWorkflowListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let!(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:deal) { account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead', status: 'lost') }

  before { allow(Workflows::TriggerService).to receive(:fire) }

  it 'fires the status change and the lost outcome of a deal' do
    event = Events::Base.new(Events::Types::CRM_DEAL_STATUS_CHANGED, Time.current,
                             { deal: deal, conversation: nil, changed_attributes: { 'status' => %w[open lost], 'updated_at' => [1, 2] } })

    listener.crm_deal_status_changed(event)

    expect(Workflows::TriggerService).to have_received(:fire)
      .with(account: account, event: 'crm_deal_status_changed', context: { 'deal_id' => deal.id, 'contact_id' => contact.id,
                                                                            'changes' => { 'status' => %w[open lost] } }, performed_by: nil)
    expect(Workflows::TriggerService).to have_received(:fire).with(hash_including(event: 'crm_deal_lost'))
  end

  it 'does not fire the lost outcome for other deal events' do
    event = Events::Base.new(Events::Types::CRM_DEAL_STAGE_CHANGED, Time.current, { deal: deal, conversation: nil })

    listener.crm_deal_stage_changed(event)

    expect(Workflows::TriggerService).to have_received(:fire).with(hash_including(event: 'crm_deal_stage_changed')).once
    expect(Workflows::TriggerService).not_to have_received(:fire).with(hash_including(event: 'crm_deal_lost'))
  end

  it 'passes who caused the event so a workflow cannot start itself' do
    workflow = account.automation_workflows.create!(name: 'Qualquer', graph: { 'nodes' => [], 'edges' => [] })
    event = Events::Base.new(Events::Types::CRM_DEAL_CREATED, Time.current, { deal: deal, conversation: nil, performed_by: workflow })

    listener.crm_deal_created(event)

    expect(Workflows::TriggerService).to have_received(:fire).with(hash_including(event: 'crm_deal_created', performed_by: workflow))
  end

  it 'fires conversation and message events with their records' do
    conversation = create(:conversation, account: account, contact: contact)
    message = create(:message, conversation: conversation, account: account, message_type: :incoming)

    listener.message_created(Events::Base.new(Events::Types::MESSAGE_CREATED, Time.current, { message: message }))

    expect(Workflows::TriggerService).to have_received(:fire).with(
      hash_including(event: 'message_created', context: { 'conversation_id' => conversation.id, 'contact_id' => contact.id, 'message_id' => message.id })
    )
  end

  it 'ignores activity messages' do
    conversation = create(:conversation, account: account, contact: contact)
    activity = create(:message, conversation: conversation, account: account, message_type: :activity)

    listener.message_created(Events::Base.new(Events::Types::MESSAGE_CREATED, Time.current, { message: activity }))

    expect(Workflows::TriggerService).not_to have_received(:fire)
  end
end
