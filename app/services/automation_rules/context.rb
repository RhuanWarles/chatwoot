module AutomationRules
  Context = Data.define(
    :account,
    :conversation,
    :contact,
    :inbox,
    :assignee,
    :team,
    :deal,
    :trigger,
    :event_changes,
    :variables
  ) do
    def self.from(conversation:, account:, trigger: nil, event_changes: {}, variables: {}, deal: nil, contact: nil)
      resolved_deal = deal || conversation&.crm_deals&.order(created_at: :desc)&.first
      resolved_contact = contact || conversation&.contact || resolved_deal&.contact
      new(
        account: account,
        conversation: conversation,
        contact: resolved_contact,
        inbox: conversation&.inbox,
        assignee: conversation&.assignee,
        team: conversation&.team,
        deal: resolved_deal,
        trigger: trigger,
        event_changes: event_changes || {},
        variables: variables || {}
      )
    end
  end
end
