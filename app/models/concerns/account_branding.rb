module AccountBranding
  extend ActiveSupport::Concern

  BRANDING_LOGO_MAX_SIZE = 1.megabyte
  BRANDING_LOGO_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  included do
    include Rails.application.routes.url_helpers
    has_one_attached :branding_logo
    validate :acceptable_branding_logo, if: -> { branding_logo.changed? }
  end

  def branding_logo_url
    return '' unless branding_logo.attached?

    url_for(branding_logo)
  end

  private

  def acceptable_branding_logo
    return unless branding_logo.attached?

    errors.add(:branding_logo, 'is too big') if branding_logo.byte_size > BRANDING_LOGO_MAX_SIZE
    return if BRANDING_LOGO_CONTENT_TYPES.include?(branding_logo.content_type)

    errors.add(:branding_logo, 'filetype not supported')
  end
end
