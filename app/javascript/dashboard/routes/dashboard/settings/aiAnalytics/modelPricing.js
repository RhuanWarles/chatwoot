// List price per 1 million tokens, in US dollars, by model. A model that is not here has no estimate ("—") instead of a
// guessed one: add it here when its price is known.
export const MODEL_PRICES = {
  'gpt-4.1': { input: 2, output: 8 },
};

const ONE_MILLION = 1_000_000;

// "gpt-4.1-2025-04-14" is the same price as "gpt-4.1".
const normalize = model =>
  String(model || '')
    .trim()
    .toLowerCase()
    .replace(/-\d{4}-\d{2}-\d{2}$/, '');

export const priceFor = model => MODEL_PRICES[normalize(model)] || null;

export const costOf = (promptTokens, completionTokens, price) =>
  (Number(promptTokens || 0) / ONE_MILLION) * price.input +
  (Number(completionTokens || 0) / ONE_MILLION) * price.output;

// `models` is the per-model usage of the period: [{ model, prompt_tokens, completion_tokens }].
// The estimate is the sum of each model priced on its own. When any model in use has no price the total would be wrong,
// so there is no estimate at all.
export const estimateCost = models => {
  const used = (models || []).filter(
    item => Number(item.prompt_tokens) + Number(item.completion_tokens) > 0
  );
  if (!used.length) return null;
  let total = 0;
  for (let index = 0; index < used.length; index += 1) {
    const price = priceFor(used[index].model);
    if (!price) return null;
    total += costOf(
      used[index].prompt_tokens,
      used[index].completion_tokens,
      price
    );
  }
  return total;
};

// The models in use that have a price, to explain where the estimate comes from.
export const pricedModels = models => {
  const seen = new Set();
  const result = [];
  (models || []).forEach(item => {
    const name = normalize(item.model);
    const price = MODEL_PRICES[name];
    if (!price || seen.has(name)) return;
    seen.add(name);
    result.push({ model: name, ...price });
  });
  return result;
};
