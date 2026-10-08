# frozen_string_literal: true

module Evolution
  class GroupParticipantsService
    CACHE_TTL = 5.minutes

    def initialize(conversation)
      @conversation = conversation
      @account = conversation.account
    end

    def perform(refresh: false, strict: false)
      return [] if conversation.additional_attributes['evolution_group_left_at'].present?

      return [] unless group_jid.present? && instance_name.present?

      invalidate! if refresh
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        normalize_participants(fetch_participants)
      end
    rescue CustomExceptions::Evolution => e
      raise if strict

      Rails.logger.warn("[Evolution] group participants unavailable: #{e.class}")
      []
    end

    def invalidate!
      Rails.cache.delete(cache_key)
    end

    private

    attr_reader :conversation, :account

    def group_jid
      Evolution::GroupContext.new(conversation).group_jid
    end

    def instance_name
      Evolution::Configuration.new(conversation.inbox).instance_name
    end

    def cache_key
      "evolution:group-participants:#{account.id}:#{instance_name}:#{group_jid}"
    end

    def fetch_participants
      payload = Evolution::GroupClient.new(conversation.inbox).get('group/participants', groupJid: group_jid)
      payload.dig('data', 'participants') || payload['participants'] || []
    end

    def normalize_participants(participants)
      normalized = participants.filter_map { |participant| normalize(participant) }
      contacts = contacts_by_phone(normalized.map { |item| item[:phone] }.compact)
      normalized.map do |participant|
        contact = contacts[participant[:phone]]
        contact_name = contact&.name.presence
        participant.merge(
          contact_id: contact&.id,
          contact_name: contact_name,
          display_name: contact_name || participant[:whatsapp_name].presence ||
            format_phone(participant[:phone]) || participant[:lid]
        )
      end
    end

    def normalize(participant)
      lid = participant['id'].to_s.presence
      jid = [participant['phoneNumber'], participant['id']].find { |value| value.to_s.match?(/\A\d+@s\.whatsapp\.net\z/) }
      return if lid.blank? && jid.blank?

      phone = jid&.delete_suffix('@s.whatsapp.net')
      {
        lid: lid,
        jid: jid,
        phone: phone,
        whatsapp_name: participant['name'].presence,
        avatar_url: participant['imgUrl'].presence,
        admin: participant['admin'].present? && participant['admin'] != 'null',
        super_admin: participant['admin'] == 'superadmin',
      }
    end

    def contacts_by_phone(phones)
      Contact.where(account_id: account.id, phone_number: phones.map { |phone| "+#{phone}" })
             .index_by { |contact| contact.phone_number.delete_prefix('+').delete(' ') }
    end

    def format_phone(phone)
      return if phone.blank?

      "+#{phone}"
    end
  end
end
