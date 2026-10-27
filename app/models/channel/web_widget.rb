# == Schema Information
#
# Table name: channel_web_widgets
#
#  id                    :integer          not null, primary key
#  allowed_domains       :text             default("")
#  branding_text         :string
#  branding_url          :string
#  continuity_via_email  :boolean          default(TRUE), not null
#  feature_flags         :integer          default(7), not null
#  hmac_mandatory        :boolean          default(FALSE)
#  hmac_token            :string
#  pre_chat_form_enabled :boolean          default(FALSE)
#  pre_chat_form_options :jsonb
#  reply_time            :integer          default("in_a_few_minutes")
#  website_token         :string
#  website_url           :string
#  welcome_tagline       :string
#  welcome_title         :string
#  widget_color          :string           default("#1f93ff")
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer
#
# Indexes
#
#  index_channel_web_widgets_on_hmac_token     (hmac_token) UNIQUE
#  index_channel_web_widgets_on_website_token  (website_token) UNIQUE
#

class Channel::WebWidget < ApplicationRecord
  include Channelable
  include FlagShihTzu
  include Rails.application.routes.url_helpers

  self.table_name = 'channel_web_widgets'
  BRANDING_LOGO_MAX_SIZE = 1.megabyte
  EDITABLE_ATTRS = [:website_url, :widget_color, :welcome_title, :welcome_tagline, :reply_time, :pre_chat_form_enabled,
                    :continuity_via_email, :hmac_mandatory, :allowed_domains,
                    :branding_text, :branding_url, :branding_logo, :remove_branding_logo,
                    { pre_chat_form_options: [:pre_chat_message, :require_email,
                                              { pre_chat_fields:
                                                [:field_type, :label, :placeholder, :name, :enabled, :type, :enabled, :required,
                                                 :locale, { values: [] }, :regex_pattern, :regex_cue] }] },
                    { selected_feature_flags: [] }].freeze

  before_validation :validate_pre_chat_options
  validates :website_url, presence: true
  validates :widget_color, presence: true
  validates :branding_text, length: { maximum: 100 }
  validates :branding_url, length: { maximum: 2048 }
  validate :acceptable_branding_url
  validate :acceptable_branding_logo, if: -> { branding_logo.changed? }
  has_many :portals, foreign_key: 'channel_web_widget_id', dependent: :nullify, inverse_of: :channel_web_widget

  has_one_attached :branding_logo
  normalizes :branding_text, :branding_url, with: ->(value) { value.strip.presence }
  after_save_commit :purge_branding_logo, if: -> { @remove_branding_logo }

  has_secure_token :website_token
  has_secure_token :hmac_token

  has_flags 1 => :attachments,
            2 => :emoji_picker,
            3 => :end_conversation,
            4 => :use_inbox_avatar_for_bot,
            5 => :allow_mobile_webview,
            :column => 'feature_flags',
            :check_for_column => false

  enum reply_time: { in_a_few_minutes: 0, in_a_few_hours: 1, in_a_day: 2 }

  def name
    'Website'
  end

  def branding_logo_url
    return '' unless branding_logo.attached?

    url_for(branding_logo)
  end

  def remove_branding_logo=(value)
    @remove_branding_logo = ActiveModel::Type::Boolean.new.cast(value)
  end

  def web_widget_script
    "
    <script>
      (function(d,t) {
        var BASE_URL=\"#{ENV.fetch('FRONTEND_URL', '')}\";
        var g=d.createElement(t),s=d.getElementsByTagName(t)[0];
        g.src=BASE_URL+\"/packs/js/sdk.js\";
        g.async = true;
        s.parentNode.insertBefore(g,s);
        g.onload=function(){
          window.chatwootSDK.run({
            websiteToken: '#{website_token}',
            baseUrl: BASE_URL
          })
        }
      })(document,\"script\");
    </script>
    "
  end

  def validate_pre_chat_options
    return if pre_chat_form_options.with_indifferent_access['pre_chat_fields'].present?

    self.pre_chat_form_options = {
      pre_chat_message: 'Share your queries or comments here.',
      pre_chat_fields: [
        {
          'field_type': 'standard', 'label': 'Email Id', 'name': 'emailAddress', 'type': 'email', 'required': true, 'enabled': false
        },
        {
          'field_type': 'standard', 'label': 'Full name', 'name': 'fullName', 'type': 'text', 'required': false, 'enabled': false
        },
        {
          'field_type': 'standard', 'label': 'Phone number', 'name': 'phoneNumber', 'type': 'text', 'required': false, 'enabled': false
        }
      ]
    }
  end

  def create_contact_inbox(additional_attributes = {})
    ::ContactInboxWithContactBuilder.new({
                                           inbox: inbox,
                                           contact_attributes: { additional_attributes: additional_attributes }
                                         }).perform
  end

  private

  # Only http(s) links are accepted: the url is rendered as a link inside the widget.
  def acceptable_branding_url
    return if branding_url.blank?

    uri = URI.parse(branding_url)
    errors.add(:branding_url, :invalid) unless uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    errors.add(:branding_url, :invalid)
  end

  def acceptable_branding_logo
    return unless branding_logo.attached?

    errors.add(:branding_logo, 'is too big') if branding_logo.byte_size > BRANDING_LOGO_MAX_SIZE
    errors.add(:branding_logo, 'filetype not supported') unless Avatarable::ALLOWED_AVATAR_CONTENT_TYPES.include?(branding_logo.content_type)
  end

  # detach clears the in-memory attachment so the same request already serves an empty logo;
  # purge_later on the attachment alone leaves it cached on the record.
  def purge_branding_logo
    @remove_branding_logo = false
    return unless branding_logo.attached?

    blob = branding_logo.blob
    branding_logo.detach
    blob.purge_later
  end
end
