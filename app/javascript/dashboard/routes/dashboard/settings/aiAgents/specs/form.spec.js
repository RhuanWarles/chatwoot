import { agentPayload, newAgent, validAgent } from '../form';

describe('AI agent configuration', () => {
  it('starts inactive and requires a prompt and model', () => {
    expect(newAgent().active).toBe(false);
    expect(newAgent().respond_to_groups).toBe(false);
    expect(validAgent(newAgent())).toBe(false);
  });

  it('validates required text and temperature without truncating prompts', () => {
    const agent = {
      ...newAgent(),
      name: 'Sales',
      model: 'model',
      system_prompt: 'Line one\n'.repeat(3000),
    };
    expect(validAgent(agent)).toBe(true);
    expect(agentPayload(agent).system_prompt).toBe(agent.system_prompt);
    [NaN, -0.1, 1.1, '0.7', ''].forEach(temperature => {
      expect(validAgent({ ...agent, temperature })).toBe(false);
    });
    expect(validAgent({ ...agent, system_prompt: '   ' })).toBe(false);
  });

  it('sends only configuration and copies relationships when editing', () => {
    const agent = {
      ...newAgent(),
      id: 10,
      account_id: 2,
      inbox_ids: [5],
      inboxes: [],
      created_at: 'date',
    };
    const payload = agentPayload(agent);
    expect(payload).not.toHaveProperty('account_id');
    expect(payload).not.toHaveProperty('id');
    payload.inbox_ids.push(6);
    expect(agent.inbox_ids).toEqual([5]);
    expect(agentPayload({ ...agent, respond_to_groups: true }).respond_to_groups).toBe(true);
  });
});
