import { describe, expect, it } from 'vitest';
import {
  distributionTotal,
  evenShares,
  isDistributionValid,
} from './distribution';

const row = (userId, percentage) => ({ user_id: userId, percentage });

describe('distributionTotal', () => {
  it('adds up the whole percentages and ignores what is not a number yet', () => {
    expect(distributionTotal([row(1, 50), row(2, 30)])).toBe(80);
    expect(distributionTotal([row(1, 50), row(2, '')])).toBe(50);
    expect(distributionTotal([])).toBe(0);
    expect(distributionTotal(undefined)).toBe(0);
  });
});

describe('isDistributionValid', () => {
  it('accepts people whose shares add up to 100', () => {
    expect(isDistributionValid([row(1, 60), row(2, 40)])).toBe(true);
    expect(isDistributionValid([row(1, 100)])).toBe(true);
  });

  it('refuses an empty list and a total that is not 100', () => {
    expect(isDistributionValid([])).toBe(false);
    expect(isDistributionValid(undefined)).toBe(false);
    expect(isDistributionValid([row(1, 60), row(2, 30)])).toBe(false);
    expect(isDistributionValid([row(1, 60), row(2, 50)])).toBe(false);
  });

  it('refuses a row without a person or without a whole share from 1 to 100', () => {
    expect(isDistributionValid([row('', 100)])).toBe(false);
    expect(isDistributionValid([row(1, 0), row(2, 100)])).toBe(false);
    expect(isDistributionValid([row(1, 50.5), row(2, 49.5)])).toBe(false);
    expect(isDistributionValid([row(1, ''), row(2, 100)])).toBe(false);
  });

  it('refuses the same person twice', () => {
    expect(isDistributionValid([row(1, 50), row('1', 50)])).toBe(false);
  });
});

describe('evenShares', () => {
  it('shares 100% as evenly as whole numbers allow, always adding up to 100', () => {
    expect(evenShares(2)).toEqual([50, 50]);
    expect(evenShares(3)).toEqual([34, 33, 33]);
    expect(evenShares(7).reduce((sum, share) => sum + share, 0)).toBe(100);
    expect(evenShares(1)).toEqual([100]);
    expect(evenShares(0)).toEqual([]);
  });
});
