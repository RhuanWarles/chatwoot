class Crm::DealLabelsService
  pattr_initialize [:account!, :user!, :deals!]

  # deal id => label titles: the contact's labels, then the labels of the contact's most recent conversation the user can access.
  def perform
    deals.to_h { |deal| [deal.id, (contact_labels[deal.contact_id].to_a + conversation_labels[deal.contact_id].to_a).uniq] }
  end

  private

  def contact_ids
    @contact_ids ||= deals.map(&:contact_id).uniq
  end

  def contact_labels
    @contact_labels ||= ActsAsTaggableOn::Tagging.joins(:tag)
                                                 .where(context: 'labels', taggable_type: 'Contact', taggable_id: contact_ids)
                                                 .order('taggings.id')
                                                 .pluck(:taggable_id, 'tags.name')
                                                 .group_by(&:first).transform_values { |rows| rows.map(&:last) }
  end

  def conversation_labels
    @conversation_labels ||= begin
      conversations = Conversations::PermissionFilterService.new(account.conversations.where(contact_id: contact_ids), user, account).perform
      conversations.select('DISTINCT ON (conversations.contact_id) conversations.contact_id, conversations.cached_label_list')
                   .reorder(:contact_id, last_activity_at: :desc)
                   .to_h { |conversation| [conversation.contact_id, conversation.cached_label_list_array] }
    end
  end
end
