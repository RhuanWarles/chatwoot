// Small geometry helpers for the hand-made SVG charts of the AI analytics screen.

// Counts are whole numbers, so the vertical axis only has whole-number ticks: 0, 1, 2... never 0.5.
export const integerTicks = (maxValue, target = 4) => {
  const max = Math.max(1, Math.ceil(Number(maxValue) || 0));
  const raw = Math.ceil(max / target);
  const magnitude = 10 ** Math.floor(Math.log10(raw));
  const step =
    [1, 2, 5, 10].map(factor => factor * magnitude).find(size => size >= raw) ??
    raw;
  const top = step * Math.ceil(max / step);
  const ticks = [];
  for (let value = 0; value <= top; value += step) ticks.push(value);
  return { max: top, step, ticks };
};

export const linePath = points =>
  points.map(([x, y], index) => `${index ? 'L' : 'M'}${x} ${y}`).join(' ');

export const areaPath = (points, baseline) => {
  if (!points.length) return '';
  const first = points[0][0];
  const last = points[points.length - 1][0];
  return `${linePath(points)} L${last} ${baseline} L${first} ${baseline} Z`;
};

// Which of `count` labels to show so that they are at least `minGap` pixels apart on `width` pixels.
export const labelIndexes = (count, width, minGap = 64) => {
  if (count <= 0) return [];
  const fit = Math.max(1, Math.floor(width / minGap));
  const every = Math.max(1, Math.ceil(count / fit));
  const indexes = [];
  for (let index = 0; index < count; index += every) indexes.push(index);
  return indexes;
};

// Labels sit at the height of their line, and lines can end at the same height. Pushes them apart, keeping the order,
// so that two labels are never drawn on top of each other. `items`: [{ id, y }].
export const spreadLabels = (items, minGap, top, bottom) => {
  const sorted = [...items].sort((a, b) => a.y - b.y);
  sorted.forEach((item, index) => {
    const floor = index ? sorted[index - 1].y + minGap : top;
    sorted[index] = { ...item, y: Math.max(item.y, floor) };
  });
  const overflow = sorted.length ? sorted[sorted.length - 1].y - bottom : 0;
  if (overflow > 0) {
    for (let index = sorted.length - 1; index >= 0; index -= 1) {
      const ceiling =
        index === sorted.length - 1 ? bottom : sorted[index + 1].y - minGap;
      sorted[index] = {
        ...sorted[index],
        y: Math.min(sorted[index].y, ceiling),
      };
    }
  }
  return Object.fromEntries(sorted.map(item => [item.id, item.y]));
};

export const nearestIndex = (position, count, left, plotWidth) => {
  if (count <= 1) return 0;
  const raw = Math.round(((position - left) / plotWidth) * (count - 1));
  return Math.min(count - 1, Math.max(0, raw));
};
