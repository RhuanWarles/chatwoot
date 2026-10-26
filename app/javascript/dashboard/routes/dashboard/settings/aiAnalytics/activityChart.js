export const nearestDataIndex = (positions, pointerX) => {
  if (!positions.length || !Number.isFinite(pointerX)) return null;

  return positions.reduce((nearest, position, index) => {
    if (nearest === null) return index;

    return Math.abs(position - pointerX) <
      Math.abs(positions[nearest] - pointerX)
      ? index
      : nearest;
  }, null);
};

export const tooltipRowsForIndex = (data, index, formatValue) =>
  (data.series || []).map(series => ({
    color: series.color,
    label: series.label,
    value: formatValue(series.data?.[index]),
  }));
