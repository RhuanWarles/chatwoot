class AddRetrievalSettingsToSaasKnowledgeBases < ActiveRecord::Migration[7.1]
  def change
    add_column :saas_knowledge_bases, :similarity_threshold, :decimal, precision: 4, scale: 3
    add_column :saas_knowledge_bases, :retrieval_top_k, :integer
    add_column :saas_knowledge_bases, :chunk_size, :integer
    add_column :saas_knowledge_bases, :chunk_overlap, :integer
  end
end
