// Shared by the specs of the AI analytics screen: an API answer shaped like the real one, with the numbers of the
// reference account (28 conversations, 198 messages, 835,121 input and 6,913 output tokens on gpt-4.1).
import { createI18n } from 'vue-i18n';
import crm from 'dashboard/i18n/locale/pt_BR/crm.json';
import saasAI from 'dashboard/i18n/locale/pt_BR/saasAI.json';

export const i18n = () =>
  createI18n({
    legacy: false,
    locale: 'pt_BR',
    messages: { pt_BR: { ...saasAI, ...crm } },
  });

const DAYS = Array.from(
  { length: 11 },
  (_, index) => `2026-11-${String(index + 1).padStart(2, '0')}`
);
const MESSAGES = [12, 0, 20, 25, 40, 16, 0, 14, 22, 18, 31];
const TURNS = [11, 0, 19, 24, 38, 15, 0, 13, 21, 17, 29];
const CONVERSATIONS = [2, 0, 4, 5, 6, 3, 0, 2, 4, 2, 3];
const TOKENS = [
  60000, 0, 95000, 120034, 140000, 90000, 0, 80000, 110000, 70000, 77000,
];

export const timeseries = () =>
  DAYS.map((date, index) => ({
    date,
    messages: MESSAGES[index],
    turns: TURNS[index],
    conversations: CONVERSATIONS[index],
    tokens: TOKENS[index],
    credits: 0,
  }));

export const analyticsPayload = (overrides = {}) => ({
  filters: {
    start_at: '2026-11-01T00:00:00Z',
    end_at: '2026-11-11T14:05:00Z',
    agent_id: null,
    inbox_id: null,
  },
  billing: {
    mode: 'byok',
    prompt_tokens: 835121,
    completion_tokens: 6913,
    total_tokens: 842034,
    estimated_cost_usd: null,
    average_cost_per_conversation: null,
    models: [
      {
        provider: 'openai',
        model: 'gpt-4.1',
        responses: 187,
        prompt_tokens: 835121,
        completion_tokens: 6913,
      },
    ],
  },
  summary: {
    conversations: 28,
    turns: 187,
    messages: 198,
    other_bot_messages: 12,
    handoffs: 1,
    handoff_rate: 3.57,
    average_response_ms: null,
  },
  timeseries: timeseries(),
  tools: {
    executions: 12,
    success: 10,
    failures: 2,
    success_rate: 83.33,
    top: [
      {
        id: 1,
        name: 'buscar_pedido',
        executions: 8,
        success: 7,
        failures: 1,
        success_rate: 87.5,
      },
      {
        id: 2,
        name: 'agendar_visita',
        executions: 4,
        success: 3,
        failures: 1,
        success_rate: 75,
      },
    ],
  },
  knowledge: {
    queries: 20,
    hits: 16,
    hit_rate: 80,
    conversations: 9,
    utilization_rate: 32.14,
    unanswered: [
      { query: 'qual o prazo de entrega?', count: 3 },
      { query: 'tem desconto para pagamento à vista?', count: 1 },
    ],
  },
  agents: [{ id: 1, name: 'Vendas' }],
  inboxes: [{ id: 5, name: 'WhatsApp' }],
  ...overrides,
});

// Nothing happened in the period.
export const emptyPayload = () =>
  analyticsPayload({
    billing: {
      mode: 'byok',
      prompt_tokens: 0,
      completion_tokens: 0,
      total_tokens: 0,
      estimated_cost_usd: null,
      average_cost_per_conversation: null,
      models: [],
    },
    summary: {
      conversations: 0,
      turns: 0,
      messages: 0,
      other_bot_messages: 0,
      handoffs: 0,
      handoff_rate: 0,
      average_response_ms: null,
    },
    timeseries: DAYS.map(date => ({
      date,
      messages: 0,
      turns: 0,
      conversations: 0,
      tokens: 0,
      credits: 0,
    })),
    tools: { executions: 0, success: 0, failures: 0, success_rate: 0, top: [] },
    knowledge: {
      queries: 0,
      hits: 0,
      hit_rate: 0,
      conversations: 0,
      utilization_rate: 0,
      unanswered: [],
    },
  });
