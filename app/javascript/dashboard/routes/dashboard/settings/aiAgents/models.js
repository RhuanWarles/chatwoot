export const SUGGESTED_MODELS = {
  openai: [
    'gpt-4.1',
    'gpt-4.1-mini',
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-5',
    'gpt-5-mini',
  ],
  anthropic: [
    'claude-3-5-sonnet-latest',
    'claude-3-5-haiku-latest',
    'claude-3-7-sonnet-latest',
  ],
  gemini: [
    'gemini-1.5-pro',
    'gemini-1.5-flash',
    'gemini-2.0-flash',
    'gemini-2.5-pro',
  ],
  openrouter: [
    'openai/gpt-4o',
    'openai/gpt-4.1',
    'anthropic/claude-3.5-sonnet',
    'google/gemini-2.0-flash-001',
  ],
  groq: [
    'llama-3.1-8b-instant',
    'llama-3.3-70b-versatile',
    'mixtral-8x7b-32768',
  ],
};

export const suggestedModelsForProvider = provider =>
  SUGGESTED_MODELS[provider] ?? [];
