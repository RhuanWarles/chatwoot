// Tool executions are presentation entries, never Message objects.
export const mergeToolExecutions = (entries, executions) => {
  if (!entries.length) return entries;
  const earliest = Math.min(...entries.map(entry => entry.createdAt));
  const tools = executions
    .map(execution => ({
      key: `tool-execution-${execution.id}`,
      createdAt: Date.parse(execution.created_at) / 1000,
      execution,
    }))
    .filter(entry => entry.createdAt >= earliest);
  return [...entries, ...tools].sort((a, b) => a.createdAt - b.createdAt);
};
