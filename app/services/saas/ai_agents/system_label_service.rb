class Saas::AiAgents::SystemLabelService
  LABEL_TITLE = 'atendida por ia'.freeze

  def self.apply!(conversation)
    label = conversation.account.labels.find_or_create_by!(title: LABEL_TITLE)
    return if conversation.labels.include?(label.title)

    conversation.add_labels(label.title)
  end
end
