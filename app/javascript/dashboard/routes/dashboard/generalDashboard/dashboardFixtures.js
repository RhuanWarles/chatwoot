// An API answer shaped like the real one, shared by the specs of the dashboard.
const DAYS = Array.from(
  { length: 7 },
  (_, index) => `2026-11-${String(index + 6).padStart(2, '0')}`
);
const AI = [38, 44, 41, 52, 47, 22, 19];
const PEOPLE = [21, 24, 19, 26, 22, 9, 8];

export const dashboardPayload = (overrides = {}) => ({
  filters: {
    start_at: '2026-11-06T00:00:00-03:00',
    end_at: '2026-11-12T14:05:00-03:00',
    inbox_id: null,
    timezone: 'America/Sao_Paulo',
    generated_at: '2026-11-12T14:05:00-03:00',
  },
  attendance: {
    activity: {
      conversations: 312,
      previous: 278,
      per_day: DAYS.map((date, index) => ({
        date,
        conversations: [38, 41, 39, 47, 52, 30, 24][index],
      })),
    },
    replies: {
      per_day: DAYS.map((date, index) => ({
        date,
        ai: AI[index],
        people: PEOPLE[index],
      })),
      ai: 263,
      people: 129,
      ai_share: 67.09,
    },
    handled: { responded: 300, ai_only: 192, ai_only_share: 64.0 },
    waiting: {
      total: 7,
      fresh: 3,
      middle: 3,
      late: 1,
      oldest_minutes: 42,
      list: [
        {
          id: 31,
          contact: 'Mercado Bela Vista',
          inbox: 'WhatsApp',
          assignee: 'Rodolpho',
          minutes: 42,
        },
        {
          id: 33,
          contact: 'Clínica Sorriso',
          inbox: 'Site',
          assignee: null,
          minutes: 35,
        },
        {
          id: 40,
          contact: 'Studio Fit',
          inbox: 'Site',
          assignee: 'Diego',
          minutes: 4,
        },
      ],
    },
    first_response: {
      average: 192,
      median: 160,
      previous_average: 234,
      count: 120,
      per_day: DAYS.map(date => ({ date, average: 190 })),
    },
    heatmap: Array.from({ length: 7 }, (_, day) =>
      Array.from({ length: 24 }, (__, hour) =>
        day === 2 && hour === 10 ? 12 : 0
      )
    ),
    agents: [
      {
        id: 1,
        name: 'Brenda',
        replies: 118,
        conversations: 90,
        first_response: 130,
        waiting: 2,
      },
      {
        id: 2,
        name: 'Rodolpho',
        replies: 94,
        conversations: 70,
        first_response: 220,
        waiting: 0,
      },
    ],
  },
  ai: {
    summary: {
      conversations: 199,
      turns: 400,
      messages: 410,
      handoffs: 18,
      handoff_rate: 9.04,
    },
    billing: {
      mode: 'byok',
      total_tokens: 842034,
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
    tools: { executions: 12, success_rate: 83.33 },
    knowledge: { queries: 20, hits: 16, hit_rate: 80 },
  },
  crm: {
    pipelines: [{ id: 1, name: 'Comercial' }],
    pipeline_id: 1,
    funnel: [
      { id: 1, name: 'Novo', deals: 48, value: 96000 },
      { id: 2, name: 'Qualificado', deals: 31, value: 124000 },
    ],
    open_value: 412000,
    won: { deals: 14, value: 86400 },
    lost: { deals: 11, value: 52000 },
    win_rate: 56,
    lost_reasons: [{ id: 5, name: 'Preço', deals: 5 }],
  },
  blasts: {
    available: true,
    sent: 1280,
    delivered: 1237,
    replied: 357,
    previous_sent: 900,
    campaigns: [
      {
        id: 3,
        title: 'Black Friday',
        channel: 'Channel::Whatsapp',
        sent: 720,
        delivered: 698,
        replied: 214,
      },
    ],
  },
  inboxes: [{ id: 5, name: 'WhatsApp' }],
  ...overrides,
});

export const emptyDashboard = () =>
  dashboardPayload({
    attendance: {
      activity: { conversations: 0, previous: 0, per_day: [] },
      replies: { per_day: [], ai: 0, people: 0, ai_share: null },
      handled: { responded: 0, ai_only: 0, ai_only_share: null },
      waiting: {
        total: 0,
        fresh: 0,
        middle: 0,
        late: 0,
        oldest_minutes: null,
        list: [],
      },
      first_response: {
        average: null,
        median: null,
        previous_average: null,
        count: 0,
        per_day: [],
      },
      heatmap: Array.from({ length: 7 }, () => Array(24).fill(0)),
      agents: [],
    },
    ai: null,
    crm: { pipelines: [], pipeline_id: null },
    blasts: {
      available: false,
      sent: 0,
      delivered: 0,
      replied: 0,
      previous_sent: 0,
      campaigns: [],
    },
  });
