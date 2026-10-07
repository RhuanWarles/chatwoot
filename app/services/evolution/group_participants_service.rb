# frozen_string_literal: true

module Evolution
  class GroupParticipantsService
    CACHE_TTL = 5.minutes
    REQUEST_TIMEOUT = 8

    def initialize(conversation)
      @conversation = conversation
      @account = conversation.account
    end

    def perform
      return [] unless group_jid.present? && instance_name.present?

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        normalize_participants(fetch_participants)
      end
    rescue HTTParty::Error, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.warn("[Evolution] group participants unavailable: #{e.class}")
      []
    end

    private

    attr_reader :conversation, :account

    def group_jid
      source_id = conversation.contact_inbox&.source_id.to_s
      return source_id if source_id.end_with?('@g.us')

      identifier = conversation.contact&.identifier.to_s
      identifier if identifier.end_with?('@g.us')
    end

    def instance_name
      channel = conversation.inbox&.channel
      channel&.respond_to?(:additional_attributes) &&
        channel.additional_attributes['evolution_instance_name'].presence ||
        ENV['EVOLUTION_INSTANCE_NAME'].presence
    end

    def base_url
      ENV.fetch('EVOLUTION_API_URL', 'https://evolution.rwhub.com.br').sub(%r{/$}, '')
    end

    def api_key
      ENV['EVOLUTION_API_KEY'].presence
    end

    def cache_key
      "evolution:group-participants:#{account.id}:#{instance_name}:#{group_jid}"
    end

    def fetch_participants
      raise HTTParty::Error, 'Evolution API key is not configured' if api_key.blank?

      response = HTTParty.get(
        "#{base_url}/group/participants/#{CGI.escape(instance_name)}",
        query: { groupJid: group_jid },
        headers: { 'apikey' => api_key, 'Accept' => 'application/json' },
        timeout: REQUEST_TIMEOUT
      )
      raise HTTParty::Error, "Evolution returned #{response.code}" unless response.success?

      payload = response.parsed_response
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
      jid = participant['phoneNumber'].to_s.presence
      return if lid.blank? && jid.blank?

      phone = jid&.delete_suffix('@s.whatsapp.net')
      {
        lid: lid,
        jid: jid,
        phone: phone,
        whatsapp_name: participant['name'].presence,
        avatar_url: participant['imgUrl'].presence,
        admin: participant['admin'].present? && participant['admin'] != 'null',
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
