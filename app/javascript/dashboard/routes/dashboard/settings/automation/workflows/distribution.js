// The people of a "distribute lead" step and the share of the leads each one gets (whole percentages that add up to 100).
export const DISTRIBUTION_TOTAL = 100;

export const distributionTotal = rows =>
  (rows || []).reduce(
    (sum, row) => sum + (Number.isInteger(row.percentage) ? row.percentage : 0),
    0
  );

const hasPerson = row => row.user_id !== '' && row.user_id != null;
const hasShare = row =>
  Number.isInteger(row.percentage) &&
  row.percentage >= 1 &&
  row.percentage <= DISTRIBUTION_TOTAL;

// Mirrors Workflows::Distribution.errors on the server.
export const isDistributionValid = rows =>
  Array.isArray(rows) &&
  rows.length > 0 &&
  rows.every(row => hasPerson(row) && hasShare(row)) &&
  new Set(rows.map(row => String(row.user_id))).size === rows.length &&
  distributionTotal(rows) === DISTRIBUTION_TOTAL;

// Shares 100% as evenly as whole numbers allow: the first people take what is left over.
export const evenShares = count => {
  if (!count) return [];
  const base = Math.floor(DISTRIBUTION_TOTAL / count);
  const extra = DISTRIBUTION_TOTAL % count;
  return Array.from(
    { length: count },
    (_, index) => base + (index < extra ? 1 : 0)
  );
};
