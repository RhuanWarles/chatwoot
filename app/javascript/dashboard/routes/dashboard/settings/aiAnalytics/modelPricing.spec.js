import { formatUsd } from './analyticsFormat';
import { costOf, estimateCost, priceFor, pricedModels } from './modelPricing';

const gpt = (prompt, completion, model = 'gpt-4.1') => ({
  model,
  prompt_tokens: prompt,
  completion_tokens: completion,
});

describe('estimateCost', () => {
  it('matches the reference account: 835,121 in + 6,913 out is about US$ 1,73', () => {
    const cost = estimateCost([gpt(835121, 6913)]);

    expect(cost).toBeCloseTo(1.725546, 6);
    expect(formatUsd(cost)).toBe('US$ 1,73');
    expect(formatUsd(cost / 28)).toBe('US$ 0,06');
  });

  it('prices input and output separately, per million tokens', () => {
    expect(costOf(1000000, 0, priceFor('gpt-4.1'))).toBe(2);
    expect(costOf(0, 1000000, priceFor('gpt-4.1'))).toBe(8);
  });

  it('sums each model on its own price', () => {
    expect(estimateCost([gpt(1000000, 0), gpt(0, 1000000)])).toBe(10);
  });

  it('has no estimate for a model without a price, even when another one has', () => {
    expect(estimateCost([gpt(1000, 100, 'unknown-model')])).toBeNull();
    expect(
      estimateCost([gpt(1000, 100), gpt(1000, 100, 'unknown-model')])
    ).toBeNull();
  });

  it('has no estimate when there was no usage', () => {
    expect(estimateCost([])).toBeNull();
    expect(estimateCost(null)).toBeNull();
    expect(estimateCost([gpt(0, 0)])).toBeNull();
  });

  it('ignores a model with no tokens when another one is priced', () => {
    expect(estimateCost([gpt(1000000, 0), gpt(0, 0, 'unknown-model')])).toBe(2);
  });

  it('treats a dated model name as the same model', () => {
    expect(priceFor('gpt-4.1-2025-04-14')).toEqual({ input: 2, output: 8 });
    expect(priceFor('GPT-4.1 ')).toEqual({ input: 2, output: 8 });
    expect(priceFor('gpt-4.1-mini')).toBeNull();
  });
});

describe('pricedModels', () => {
  it('lists each model in use that has a price once', () => {
    expect(
      pricedModels([gpt(1, 1), gpt(2, 2), gpt(1, 1, 'unknown-model')])
    ).toEqual([{ model: 'gpt-4.1', input: 2, output: 8 }]);
  });
});
