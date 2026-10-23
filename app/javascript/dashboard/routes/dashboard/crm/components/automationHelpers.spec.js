import { MAX_MESSAGE_LENGTH, isAutomationValid } from './automationHelpers';

describe('isAutomationValid', () => {
  it.each([
    [{ type: 'set_status', status: 'won' }, true],
    [{ type: 'set_status', status: 'open' }, true],
    [{ type: 'set_status', status: 'archived' }, false],
    [{ type: 'assign_owner', user_id: 7 }, true],
    [{ type: 'assign_owner', user_id: null }, false],
    [
      {
        type: 'create_activity',
        activity_type: 'call',
        title: 'Call',
        due_in_hours: 2,
      },
      true,
    ],
    [
      {
        type: 'create_activity',
        activity_type: 'call',
        title: 'Call',
        due_in_hours: 2160,
      },
      true,
    ],
    [
      {
        type: 'create_activity',
        activity_type: 'call',
        title: 'Call',
        due_in_hours: 2161,
      },
      false,
    ],
    [
      {
        type: 'create_activity',
        activity_type: 'call',
        title: ' ',
        due_in_hours: 2,
      },
      false,
    ],
    [{ type: 'add_label', label: 'vip' }, true],
    [{ type: 'add_label', label: '' }, false],
    [{ type: 'set_ai_state', state: 'human' }, true],
    [{ type: 'send_message', content: 'Olá {{first_name}}' }, true],
    [{ type: 'send_message', content: '  ' }, false],
    [{ type: 'move_stage', pipeline_id: 1, stage_id: 2 }, true],
    [{ type: 'move_stage', pipeline_id: 1, stage_id: null }, false],
    [{ type: 'send_webhook', url: 'https://example.com/hook' }, true],
    [{ type: 'send_webhook', url: 'example.com/hook' }, false],
    [{ type: 'send_webhook', url: '' }, false],
    [{ type: 'unknown' }, false],
  ])('validates %j as %s', (action, expected) => {
    expect(isAutomationValid(action)).toBe(expected);
  });

  it('limits the message length', () => {
    const message = length => ({
      type: 'send_message',
      content: 'a'.repeat(length),
    });
    expect(isAutomationValid(message(MAX_MESSAGE_LENGTH))).toBe(true);
    expect(isAutomationValid(message(MAX_MESSAGE_LENGTH + 1))).toBe(false);
  });

  it.each([
    [{ id: 1, stages: [{ id: 2 }] }, true],
    [{ id: 1, stages: [{ id: 3 }] }, false],
  ])('checks a move destination %j as %s', (pipeline, expected) => {
    const action = { type: 'move_stage', pipeline_id: 1, stage_id: 2 };
    expect(isAutomationValid(action, { destinations: [pipeline] })).toBe(
      expected
    );
  });
});
