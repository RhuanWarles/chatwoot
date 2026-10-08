require 'vips'

class Evolution::UpdateGroupPictureService
  MAX_FILE_SIZE = 5.megabytes
  MAX_PIXELS = 20_000_000
  CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  def initialize(conversation:, picture:)
    unless picture.is_a?(ActionDispatch::Http::UploadedFile) && picture.size.positive? && picture.size <= MAX_FILE_SIZE &&
           CONTENT_TYPES.include?(Marcel::MimeType.for(picture.tempfile))
      raise CustomExceptions::Evolution, :invalid_picture
    end

    @context = Evolution::GroupContext.new(conversation)
    image = Vips::Image.new_from_file(picture.tempfile.path, access: :sequential)
    raise CustomExceptions::Evolution, :invalid_picture if image.width * image.height > MAX_PIXELS

    @image = image.write_to_buffer('.jpg')
  rescue Vips::Error
    raise CustomExceptions::Evolution, :invalid_picture
  end

  def perform
    @context.conversation.with_lock do
      @context.require_admin!(@context.participants)
      image = Base64.strict_encode64(@image)
      begin
        response = @context.client.post('group/updateGroupPicture', { groupJid: @context.group_jid, image: image })
      ensure
        @context.invalidate!
      end
      raise CustomExceptions::Evolution, :unconfirmed unless response['update'] == 'success'

      # Keep a durable native avatar, rather than the expiring WhatsApp CDN URL.
      @context.conversation.contact.avatar.attach(
        io: StringIO.new(@image), filename: 'group-avatar.jpg', content_type: 'image/jpeg'
      )
      @context.conversation.contact.save!
    end
  end
end
