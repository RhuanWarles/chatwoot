class Api::V1::Accounts::KnowledgeDocumentsController < Api::V1::Accounts::KnowledgeBasesController
  skip_before_action :fetch_base
  before_action :fetch_document_base
  before_action :fetch_document, only: [:show, :update, :destroy, :reindex]
  FILE_TYPES = { 'pdf' => ['application/pdf'], 'txt' => ['text/plain'], 'md' => ['text/plain', 'text/markdown'] }.freeze

  def index
    render json: { documents: @base.documents.order(created_at: :desc).map(&:public_data) }
  end

  def show
    render json: @document.public_data(detailed: true)
  end

  def create
    attributes, upload = document_params
    document = @base.with_lock do
      raise CustomExceptions::SaasError, 'document_limit' if @base.documents.count >= Saas::KnowledgeDocument::MAX_DOCUMENTS

      item = @base.documents.build(attributes.merge(indexing_version: SecureRandom.uuid))
      item.file.attach(upload) if upload
      item.save!
      item
    end
    render json: document.public_data, status: :created
  end

  def update
    attributes, upload = document_params
    @document.with_lock do
      @document.file.attach(upload) if upload
      @document.reindex!(attributes)
    end
    render json: @document.public_data
  end

  def reindex
    @document.reindex!
    render json: @document.public_data
  end

  def destroy
    @document.destroy!
    head :no_content
  end

  private

  def fetch_document_base
    @base = Current.account.saas_knowledge_bases.find(params[:knowledge_base_id])
  end

  def fetch_document
    @document = @base.documents.find(params[:id])
  end

  def document_params
    input = params.require(:document)
    unless input.is_a?(ActionController::Parameters) && (input.keys - %w[name content file]).empty? &&
           input[:name].is_a?(String) && input[:name].strip.present? && input[:name].length <= 200
      raise CustomExceptions::SaasError, 'invalid_document'
    end

    input[:file] ? uploaded_document(input) : manual_document(input)
  end

  def uploaded_document(input)
    upload = input[:file]
    raise CustomExceptions::SaasError, 'invalid_file' unless upload.is_a?(ActionDispatch::Http::UploadedFile)

    extension = File.extname(upload.original_filename).delete_prefix('.').downcase
    types = FILE_TYPES[extension]
    unless types && upload.size.positive? && upload.size <= Saas::KnowledgeDocument::MAX_FILE_SIZE &&
           types.include?(upload.content_type) && types.include?(Marcel::MimeType.for(upload.tempfile, name: upload.original_filename))
      raise CustomExceptions::SaasError, 'invalid_file'
    end

    [{ name: input[:name], source_type: extension }, upload]
  end

  def manual_document(input)
    content = input[:content]
    unless content.is_a?(String) && content.strip.present? && content.length <= Saas::KnowledgeDocument::MAX_TEXT_LENGTH
      raise CustomExceptions::SaasError, 'invalid_document'
    end

    [{ name: input[:name], content: content, source_type: 'manual' }, nil]
  end
end
