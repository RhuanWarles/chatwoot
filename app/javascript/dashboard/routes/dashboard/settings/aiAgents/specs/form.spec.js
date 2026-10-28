import {
  agentPayload,
  newAgent,
  validAgent,
  normalizeGroupPhone,
  validGroupBlacklist,
} from '../form';

describe('AI agent configuration', () => {
  it('defaults the group blacklist for new and older agents and copies it in payloads', () => {
    expect(newAgent().group_response_blacklist).toEqual([]);
    const oldAgent = { ...newAgent() };
    delete oldAgent.group_response_blacklist;
    expect(agentPayload(oldAgent).group_response_blacklist).toEqual([]);
    const agent = {
      ...newAgent(),
      group_response_blacklist: ['+55 (62) 99999-1111', '5562999991111'],
    };
    const payload = agentPayload(agent);
    expect(payload.group_response_blacklist).toEqual(['5562999991111']);
    payload.group_response_blacklist.push('5562988882222');
    expect(agent.group_response_blacklist).toHaveLength(2);
    expect(
      agentPayload({ ...agent, respond_to_groups: false })
        .group_response_blacklist
    ).toEqual(['5562999991111']);
  });

  it('normalizes international phones and rejects malformed lists', () => {
    expect(normalizeGroupPhone('55 62 99999-1111')).toBe('5562999991111');
    expect(normalizeGroupPhone('55 62 9999-1111')).toBe('5562999991111');
    expect(normalizeGroupPhone('+290 1234')).toBe('2901234');
    expect(validGroupBlacklist([])).toBe(true);
    [null, {}, [''], [null], [123456789], [{}], ['abc1234567']].forEach(value =>
      expect(validGroupBlacklist(value)).toBe(false)
    );
    expect(
      validAgent({
        ...newAgent(),
        name: 'AI',
        model: 'model',
        system_prompt: 'Help',
        group_response_blacklist: ['invalid'],
      })
    ).toBe(false);
  });
  it('starts inactive and requires a prompt and model', () => {
    expect(newAgent().active).toBe(false);
    expect(newAgent().respond_to_groups).toBe(false);
    expect(newAgent().context_messages_limit).toBe(20);
    expect(newAgent().response_delay_seconds).toBe(2);
    expect(newAgent().split_response_messages).toBe(true);
    expect(newAgent().attachment_interpretation_enabled).toBe(false);
    expect(newAgent().timezone).toBe('America/Sao_Paulo');
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
    expect(
      agentPayload({ ...agent, timezone: ' Europe/Lisbon ' }).timezone
    ).toBe('Europe/Lisbon');
    [NaN, -0.1, 1.1, '0.7', ''].forEach(temperature => {
      expect(validAgent({ ...agent, temperature })).toBe(false);
    });
    expect(validAgent({ ...agent, system_prompt: '   ' })).toBe(false);
    expect(validAgent({ ...agent, timezone: '   ' })).toBe(false);
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
    expect(
      agentPayload({ ...agent, respond_to_groups: true }).respond_to_groups
    ).toBe(true);
    expect(
      agentPayload({ ...agent, attachment_interpretation_enabled: true })
        .attachment_interpretation_enabled
    ).toBe(true);
    expect(
      agentPayload({ ...agent, context_messages_limit: 5 })
        .context_messages_limit
    ).toBe(5);
    const linked = agentPayload({
      ...agent,
      knowledge_base_ids: undefined,
      knowledge_bases: [{ id: 3 }],
    });
    expect(linked.knowledge_base_ids).toEqual([3]);
    linked.knowledge_base_ids.push(4);
    expect(agent.knowledge_base_ids).toEqual([]);
  });
});
