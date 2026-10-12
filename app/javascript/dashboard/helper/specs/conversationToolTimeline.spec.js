import {
  mergeConversationEvents,
  mergeToolExecutions,
} from '../conversationToolTimeline';
import portuguese from '../../i18n/locale/pt_BR/conversation.json';

describe('conversation tool timeline', () => {
  it('preserves Portuguese accents in the execution labels', () => {
    expect(portuguese.CONVERSATION.TOOL_EXECUTIONS.TITLE).toBe(
      'Execuções de ferramentas'
    );
    expect(portuguese.CONVERSATION.TOOL_EXECUTIONS.ERROR).toContain(
      'Não foi possível'
    );
  });
  it('places a subsecond execution before its AI reply without reordering Messages', () => {
    const inbound = { key: 'inbound', createdAt: 100, message: { id: 1 } };
    const reply = {
      key: 'reply',
      createdAt: 100,
      message: {
        id: 2,
        contentAttributes: { generatedByAi: true, aiAgentId: 1 },
      },
    };
    const execution = {
      id: 1,
      agent: { id: 1 },
      created_at: new Date(100500).toISOString(),
    };
    const timeline = mergeToolExecutions([inbound, reply], [execution]);
    expect(timeline.map(entry => entry.key)).toEqual([
      'inbound',
      'tool-execution-1',
      'reply',
    ]);
  });
  it('places executions between the inbound message and reply without creating Messages', () => {
    const entries = [
      { key: 'inbound', createdAt: 100, message: { id: 1 } },
      { key: 'reply', createdAt: 103, message: { id: 2 } },
    ];
    const execution = {
      id: 9,
      created_at: new Date(102000).toISOString(),
      status: 'completed',
    };
    const timeline = mergeToolExecutions(entries, [execution]);
    expect(timeline.map(entry => entry.key)).toEqual([
      'inbound',
      'tool-execution-9',
      'reply',
    ]);
    expect(timeline[1].message).toBeUndefined();
    expect(entries).toHaveLength(2);
  });

  it('includes older executions only when message pagination reaches their date', () => {
    const execution = { id: 1, created_at: new Date(1000).toISOString() };
    expect(mergeToolExecutions([{ createdAt: 10 }], [execution])).toHaveLength(
      1
    );
    expect(
      mergeToolExecutions([{ createdAt: 0 }, { createdAt: 10 }], [execution])
    ).toHaveLength(3);
    expect(mergeToolExecutions([], [execution])).toEqual([]);
  });

  it('adds retrieval events without turning them into messages', () => {
    const entries = [{ key: 'inbound', createdAt: 100, message: { id: 1 } }];
    const retrieval = { id: 4, created_at: new Date(101000).toISOString() };
    const timeline = mergeConversationEvents(entries, [], [retrieval]);

    expect(timeline.map(entry => entry.key)).toEqual([
      'inbound',
      'knowledge-retrieval-4',
    ]);
    expect(timeline[1].message).toBeUndefined();
    expect(timeline[1].retrieval).toBe(retrieval);
  });
});
