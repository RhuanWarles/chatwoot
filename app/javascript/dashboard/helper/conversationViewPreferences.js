export const CONVERSATION_VIEW_PREFERENCE_DEFAULTS = Object.freeze({
  tabs: Object.freeze({
    me: true,
    unassigned: true,
    all: true,
    unanswered: true,
    handoff_requested: true,
  }),
  filters: Object.freeze({
    assistant: true,
    inbox: true,
    tag: true,
    ai: true,
  }),
});

export const normalizeConversationViewPreferences = preferences => {
  const tabs = {
    ...CONVERSATION_VIEW_PREFERENCE_DEFAULTS.tabs,
    ...(preferences?.tabs || {}),
  };
  const filters = {
    ...CONVERSATION_VIEW_PREFERENCE_DEFAULTS.filters,
    ...(preferences?.filters || {}),
  };

  if (!Object.values(tabs).some(Boolean)) {
    Object.assign(tabs, CONVERSATION_VIEW_PREFERENCE_DEFAULTS.tabs);
  }

  return { tabs, filters };
};
