json.partial! 'api/v1/models/agent', formats: [:json], resource: @agent
json.inbox_ids agent_inbox_ids(@agent)
