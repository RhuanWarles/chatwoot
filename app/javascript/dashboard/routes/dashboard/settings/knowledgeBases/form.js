export const DEFAULTS = {
  name: '',
  description: '',
  active: true,
  similarity_threshold: 0.35,
  retrieval_top_k: 5,
  chunk_size: 2400,
  chunk_overlap: 240,
};

// The form of a saved base: the API returns null for the settings the account never changed, and the
// effective_* values say what is actually in use.
export const formFromBase = data => ({
  ...DEFAULTS,
  ...data,
  description: data.description ?? '',
  similarity_threshold:
    data.similarity_threshold == null
      ? data.effective_similarity_threshold
      : Number(data.similarity_threshold),
  retrieval_top_k: data.retrieval_top_k ?? data.effective_retrieval_top_k,
  chunk_size: data.chunk_size ?? data.effective_chunk_size,
  chunk_overlap: data.chunk_overlap ?? data.effective_chunk_overlap,
  initialChunkSize: data.effective_chunk_size,
  initialChunkOverlap: data.effective_chunk_overlap,
});
