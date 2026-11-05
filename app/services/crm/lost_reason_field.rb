# A select field that always holds why a deal was lost, so the automations that look at custom fields (route by field,
# conditions, "field changed") can react to the reason. The system creates it with the first reason and keeps its options
# equal to the reasons; each deal gets the name of its reason when it is lost and loses it when it is reopened.
class Crm::LostReasonField
  NAME = 'Motivo da perda'.freeze
  KEY = 'motivo_da_perda'.freeze

  class << self
    def for(account)
      account.crm_custom_fields.find_by(system_key: Crm::CustomField::LOST_REASON_KEY)
    end

    # Creates the field when there is a reason to hold, updates its options and fills the lost deals that miss the value.
    def sync!(account)
      field = self.for(account) || create_field(account)
      return unless field

      options = options_for(account, field)
      field.update!(options: options) if options.present? && field.options != options
      backfill(account, field)
      field
    end

    # Called when a reason is renamed, so the deals that were lost for it keep matching.
    def rename_values(account, from, to)
      field = self.for(account)
      return unless field && from.present? && to.present?

      held = Crm::DealCustomFieldValue.where(account_id: account.id, custom_field_id: field.id, value: from)
      held.update_all(value: to, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end

    # Runs inside the save of the deal. A person marking a deal as lost must never be stopped by the field, so the option is
    # added first, and nothing is written when the account has no such field yet.
    def write(deal)
      field = self.for(deal.account)
      return request_sync(deal.account) unless field

      record = deal.custom_field_values.find_or_initialize_by(custom_field_id: field.id)
      name = deal.status == 'lost' ? deal.lost_reason&.name : nil
      name.present? ? store_reason(field, record, deal, name) : clear(record)
    end

    private

    # An account whose reasons existed before the field did gets the field on the first deal that is lost.
    def request_sync(account)
      Crm::LostReasonFieldSyncJob.perform_later(account.id) if account.crm_lost_reasons.exists?
    end

    def create_field(account)
      return unless account.crm_lost_reasons.exists?

      key = account.crm_custom_fields.exists?(key: KEY) ? "#{KEY}_#{SecureRandom.hex(2)}" : KEY
      account.crm_custom_fields.create!(
        name: NAME, key: key, field_type: 'select', options: account.crm_lost_reasons.order(:name).pluck(:name),
        position: account.crm_custom_fields.maximum(:position).to_i + 1, system_key: Crm::CustomField::LOST_REASON_KEY
      )
    end

    # The reasons plus whatever deals still hold, so a deleted reason never leaves a value without its option.
    def options_for(account, field)
      stored = Crm::DealCustomFieldValue.where(account_id: account.id, custom_field_id: field.id).distinct.pluck(:value)
      (account.crm_lost_reasons.order(:name).pluck(:name) + stored).compact_blank.uniq
    end

    def store_reason(field, record, deal, name)
      field.update!(options: field.options | [name]) unless field.options.include?(name)
      store(record, deal, name)
    end

    def clear(record)
      record.destroy! if record.persisted?
    end

    def store(record, deal, name)
      record.account_id = deal.account_id
      record.automation_depth = deal.automation_depth.to_i
      record.typed_value = name
      record.save!
    end

    # Old deals get their value without starting automations: only a deal that is lost now starts them.
    def backfill(account, field)
      existing = Crm::DealCustomFieldValue.where(custom_field_id: field.id).pluck(:deal_id, :value).to_h
      rows = []
      account.crm_deals.where(status: 'lost').where.not(lost_reason_id: nil).includes(:lost_reason).find_each do |deal|
        name = deal.lost_reason&.name
        next if name.blank? || existing[deal.id] == name

        rows << { account_id: account.id, deal_id: deal.id, custom_field_id: field.id, value: name }
      end
      rows.each_slice(500) do |slice|
        # rubocop:disable Rails/SkipsModelValidations
        Crm::DealCustomFieldValue.upsert_all(slice, unique_by: :idx_crm_deal_custom_values_unique, update_only: [:value])
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
  end
end
