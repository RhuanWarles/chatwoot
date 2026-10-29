json.array! @executions do |execution|
  json.id execution.id
  json.action_name execution.action_name
  json.trigger execution.trigger
  json.status execution.status
  json.contact_id execution.contact_id
  json.deal_id execution.crm_deal_id
  json.error_message execution.error_message if execution.error_message.present?
  json.metadata execution.metadata
  json.started_at execution.started_at
  json.completed_at execution.completed_at
  json.created_at execution.created_at
end
