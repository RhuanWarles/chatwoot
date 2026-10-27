import { describe, expect, it } from 'vitest';
import { normalizeConversationViewPreferences } from '../conversationViewPreferences';

describe('conversation view preferences', () => {
  it('defaults every tab and filter to visible', () => {
    expect(normalizeConversationViewPreferences()).toEqual({
      tabs: { me: true, unassigned: true, all: true, unanswered: true },
      filters: { assistant: true, inbox: true, tag: true, ai: true },
    });
  });

  it('preserves a user preference while filling missing values', () => {
    expect(
      normalizeConversationViewPreferences({
        tabs: { me: false },
        filters: { ai: false },
      })
    ).toEqual({
      tabs: { me: false, unassigned: true, all: true, unanswered: true },
      filters: { assistant: true, inbox: true, tag: true, ai: false },
    });
  });

  it('restores defaults if every tab is hidden', () => {
    expect(
      normalizeConversationViewPreferences({
        tabs: { me: false, unassigned: false, all: false, unanswered: false },
      }).tabs
    ).toEqual({ me: true, unassigned: true, all: true, unanswered: true });
  });
});
