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
  const timeline = [...entries];
  tools
    .sort((a, b) => a.createdAt - b.createdAt)
    .forEach(tool => {
      const index = timeline.findIndex(entry => {
        // Messages expose whole seconds; executions retain subsecond precision.
        // Keep an execution before its agent's reply in the same second.
        const attributes = entry.message?.contentAttributes;
        const sameSecondReply =
          attributes?.generatedByAi &&
          attributes.aiAgentId === tool.execution.agent?.id &&
          Math.floor(entry.createdAt) === Math.floor(tool.createdAt);
        return entry.createdAt > tool.createdAt || sameSecondReply;
      });
      timeline.splice(index === -1 ? timeline.length : index, 0, tool);
    });
  return timeline;
};

export const mergeConversationEvents = (entries, executions, retrievals) => {
  const timeline = mergeToolExecutions(entries, executions);
  const earliest = entries.length
    ? Math.min(...entries.map(entry => entry.createdAt))
    : null;
  const knowledge = retrievals.map(retrieval => ({
    key: `knowledge-retrieval-${retrieval.id}`,
    createdAt: Date.parse(retrieval.created_at) / 1000,
    retrieval,
  })).filter(entry => earliest === null || entry.createdAt >= earliest);
  knowledge.sort((a, b) => a.createdAt - b.createdAt).forEach(item => {
    const index = timeline.findIndex(entry => entry.createdAt > item.createdAt);
    timeline.splice(index === -1 ? timeline.length : index, 0, item);
  });
  return timeline;
};
