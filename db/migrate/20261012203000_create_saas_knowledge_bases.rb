class CreateSaasKnowledgeBases < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'vector' unless extension_enabled?('vector')
    create_bases
    create_documents
    create_chunks
    create_agent_links
  end

  private

  def create_bases
    create_table :saas_knowledge_bases do |t|
      t.references :account, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end
  end

  def create_documents
    create_table :saas_knowledge_documents do |t|
      t.references :knowledge_base, null: false, index: true
      t.string :name, null: false
      t.string :source_type, null: false
      t.string :status, null: false, default: 'processing'
      t.text :content
      t.string :checksum
      t.string :embedding_model
      t.string :indexing_version, null: false
      t.string :error_code
      t.datetime :indexed_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
  end

  def create_chunks
    create_table :saas_knowledge_chunks do |t|
      t.references :account, null: false
      t.references :knowledge_document, null: false, index: true
      t.text :content, null: false
      t.integer :position, null: false
      t.integer :token_count, null: false
      t.vector :embedding, limit: 1536, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :saas_knowledge_chunks, [:knowledge_document_id, :position], unique: true, name: 'index_saas_knowledge_chunk_position'
  end

  def create_agent_links
    create_table :saas_ai_agent_knowledge_bases do |t|
      t.references :ai_agent, null: false
      t.references :knowledge_base, null: false
      t.timestamps
    end
    add_index :saas_ai_agent_knowledge_bases, [:ai_agent_id, :knowledge_base_id], unique: true, name: 'index_saas_agent_knowledge_base_unique'
  end
end
