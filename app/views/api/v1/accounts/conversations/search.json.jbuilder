json.meta do
  json.mine_count @conversations_count[:mine_count]
  json.unassigned_count @conversations_count[:unassigned_count]
  json.all_count @conversations_count[:all_count]
  json.handoff_count @conversations_count[:handoff_count]
end
json.payload do
  json.array! @conversations do |conversation|
    json.partial! 'api/v1/models/conversation', formats: [:json], conversation: conversation
  end
end
