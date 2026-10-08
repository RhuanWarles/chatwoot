class ConversationGroupPolicy < ConversationPolicy
  def manage?
    show? && account_user&.administrator?
  end
end
