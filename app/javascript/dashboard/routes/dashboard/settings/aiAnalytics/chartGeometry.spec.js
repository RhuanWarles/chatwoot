import {
  areaPath,
  integerTicks,
  labelIndexes,
  linePath,
  nearestIndex,
  spreadLabels,
} from './chartGeometry';

describe('integerTicks', () => {
  it('only produces whole-number ticks', () => {
    [1, 2, 3, 7, 9, 13, 48, 120, 999].forEach(max => {
      const { ticks } = integerTicks(max);
      expect(ticks.every(Number.isInteger)).toBe(true);
      expect(ticks[0]).toBe(0);
      expect(ticks[ticks.length - 1]).toBeGreaterThanOrEqual(max);
    });
  });

  it('uses a round step', () => {
    expect(integerTicks(9).ticks).toEqual([0, 5, 10]);
    expect(integerTicks(1).ticks).toEqual([0, 1]);
    expect(integerTicks(4).ticks).toEqual([0, 1, 2, 3, 4]);
    expect(integerTicks(120).ticks).toEqual([0, 50, 100, 150]);
  });

  it('still draws an axis when there is nothing to show', () => {
    expect(integerTicks(0).ticks).toEqual([0, 1]);
    expect(integerTicks(undefined).ticks).toEqual([0, 1]);
  });
});

describe('paths', () => {
  it('draws a line and closes an area down to the baseline', () => {
    const points = [
      [0, 10],
      [10, 5],
    ];
    expect(linePath(points)).toBe('M0 10 L10 5');
    expect(areaPath(points, 20)).toBe('M0 10 L10 5 L10 20 L0 20 Z');
    expect(areaPath([], 20)).toBe('');
  });
});

describe('labelIndexes', () => {
  it('labels every point when they fit', () => {
    expect(labelIndexes(5, 600)).toEqual([0, 1, 2, 3, 4]);
  });

  it('skips points to keep the labels apart', () => {
    expect(labelIndexes(30, 320)).toEqual([0, 6, 12, 18, 24]);
    expect(labelIndexes(0, 320)).toEqual([]);
  });
});

describe('spreadLabels', () => {
  it('moves labels that would overlap apart, keeping their order', () => {
    const y = spreadLabels(
      [
        { id: 'a', y: 100 },
        { id: 'b', y: 100 },
        { id: 'c', y: 102 },
      ],
      14,
      10,
      300
    );
    expect(y.b - y.a).toBeGreaterThanOrEqual(14);
    expect(y.c - y.b).toBeGreaterThanOrEqual(14);
  });

  it('leaves labels that already have room where they are', () => {
    expect(
      spreadLabels(
        [
          { id: 'a', y: 50 },
          { id: 'b', y: 120 },
        ],
        14,
        10,
        300
      )
    ).toEqual({ a: 50, b: 120 });
  });

  it('pushes labels back up when they would leave the bottom', () => {
    const y = spreadLabels(
      [
        { id: 'a', y: 298 },
        { id: 'b', y: 299 },
      ],
      14,
      10,
      300
    );
    expect(y.b).toBeLessThanOrEqual(300);
    expect(y.b - y.a).toBeGreaterThanOrEqual(14);
  });
});

describe('nearestIndex', () => {
  it('finds the point under the pointer and clamps to the ends', () => {
    expect(nearestIndex(100, 11, 0, 100)).toBe(10);
    expect(nearestIndex(50, 11, 0, 100)).toBe(5);
    expect(nearestIndex(-30, 11, 0, 100)).toBe(0);
    expect(nearestIndex(500, 11, 0, 100)).toBe(10);
    expect(nearestIndex(40, 1, 0, 100)).toBe(0);
  });
});
