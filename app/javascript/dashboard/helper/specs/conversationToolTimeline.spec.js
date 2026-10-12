import { mergeToolExecutions } from '../conversationToolTimeline';

describe('conversation tool timeline', () => {
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
});
