import {
  newVoiceAgent,
  voiceAgentPayload,
  validVoiceAgent,
} from '../voiceForm';

describe('voice agent configuration', () => {
  const providers = ['vapi'];
  const range = [10, 3600];
  it('starts with an inactive draft and no call automation', () => {
    expect(newVoiceAgent()).toMatchObject({
      active: false,
      inbound_enabled: false,
      outbound_enabled: false,
      assistant_id: '',
      phone_number_id: '',
      max_call_duration: null,
    });
    expect(validVoiceAgent(newVoiceAgent(), providers, range)).toBe(false);
    expect(
      validVoiceAgent(
        { ...newVoiceAgent(), name: 'Fernanda' },
        providers,
        range
      )
    ).toBe(true);
  });
  it('validates provider, identifiers and duration before saving', () => {
    const agent = {
      ...newVoiceAgent(),
      name: 'Fernanda',
      max_call_duration: 120,
    };
    expect(validVoiceAgent(agent, providers, range)).toBe(true);
    [1, 3601, 10.5, '120'].forEach(max_call_duration => {
      expect(
        validVoiceAgent({ ...agent, max_call_duration }, providers, range)
      ).toBe(false);
    });
    expect(
      validVoiceAgent({ ...agent, provider: 'retell' }, providers, range)
    ).toBe(false);
    expect(
      validVoiceAgent(
        { ...agent, phone_number_id: 'x'.repeat(101) },
        providers,
        range
      )
    ).toBe(false);
  });
  it('preserves only voice configuration without secrets or tenant identifiers', () => {
    const agent = {
      ...newVoiceAgent(),
      name: 'Fernanda',
      inbound_enabled: true,
      account_id: 10,
      api_key: 'secret',
    };
    const payload = voiceAgentPayload(agent);
    expect(payload.inbound_enabled).toBe(true);
    expect(payload).not.toHaveProperty('account_id');
    expect(payload).not.toHaveProperty('api_key');
  });
});
