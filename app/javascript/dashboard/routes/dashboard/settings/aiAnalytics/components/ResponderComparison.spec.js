import { flushPromises, mount } from '@vue/test-utils';

import aiAnalyticsAPI from 'dashboard/api/aiAnalytics';
import { i18n } from '../analyticsFixtures';
import ResponderComparison from './ResponderComparison.vue';

vi.mock('dashboard/api/aiAnalytics', () => ({
  default: { replies: vi.fn() },
}));
vi.mock('shared/composables/useLocale', () => ({
  useLocale: () => ({ resolvedLocale: { value: 'pt-BR' } }),
}));

const Select = {
  props: ['modelValue', 'options'],
  emits: ['update:modelValue'],
  template:
    '<select :value="modelValue" @change="$emit(\'update:modelValue\', Number($event.target.value))"><option v-for="option in options" :key="option.value" :value="option.value">{{ option.label }}</option></select>',
};
const TagMultiSelectComboBox = {
  props: ['modelValue', 'options', 'placeholder'],
  emits: ['update:modelValue'],
  template:
    '<div class="multi"><button v-for="option in options" :key="option.value" type="button" @click="$emit(\'update:modelValue\', [option.value])">{{ option.label }}</button></div>',
};

const report = overrides => ({
  filters: {},
  months: [
    {
      month: '2026-09',
      ai_replies: 30,
      human_replies: 70,
      ai_share: 30.0,
      conversations: { total: 10, ai_only: 2, human_only: 6, mixed: 2 },
      ai_only_share: 20.0,
    },
    {
      month: '2026-10',
      ai_replies: 60,
      human_replies: 40,
      ai_share: 60.0,
      conversations: { total: 10, ai_only: 5, human_only: 3, mixed: 2 },
      ai_only_share: 50.0,
    },
  ],
  totals: {
    ai_replies: 90,
    human_replies: 110,
    ai_share: 45.0,
    conversations: 20,
    ai_only_share: 35.0,
  },
  people: [
    { id: 7, name: 'Brenda' },
    { id: 8, name: 'Rodolpho' },
  ],
  segments: [{ id: 1, name: 'Restaurantes' }],
  ...overrides,
});

const mountReport = () =>
  mount(ResponderComparison, {
    global: {
      plugins: [i18n()],
      stubs: { Select, TagMultiSelectComboBox },
    },
  });
// The filters are behind the "Filtros" button.
const openFilters = async wrapper => {
  await wrapper.find('[data-test="filters-button"]').trigger('click');
};

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date(2026, 9, 20, 12));
  aiAnalyticsAPI.replies.mockResolvedValue({ data: report() });
});
afterEach(() => {
  vi.useRealTimers();
});

describe('ResponderComparison', () => {
  it('asks for the last 6 months with no filter and says so in the period chip', async () => {
    const wrapper = mountReport();
    await flushPromises();

    expect(aiAnalyticsAPI.replies).toHaveBeenCalledWith({
      months: 6,
      owner_ids: [],
      answered_by: [],
      segment_ids: [],
    });
    expect(wrapper.find('[data-test="card-period"]').text()).toBe(
      'Últimos 6 meses'
    );
  });

  it('changes the period from the card and reloads', async () => {
    const wrapper = mountReport();
    await flushPromises();

    await wrapper.find('[data-test="months-select"]').setValue('12');
    await flushPromises();

    expect(aiAnalyticsAPI.replies).toHaveBeenLastCalledWith(
      expect.objectContaining({ months: 12 })
    );
  });

  it('shows the three tiles, the bars and the totals with their share', async () => {
    const wrapper = mountReport();
    await flushPromises();

    expect(wrapper.find('[data-test="total-share"]').text()).toContain('45%');
    expect(wrapper.find('[data-test="ai-only-share"]').text()).toContain('35%');
    expect(wrapper.find('[data-test="replies-total"]').text()).toContain('200');
    expect(wrapper.findAll('[data-test="month-bar"]')).toHaveLength(2);
    expect(wrapper.find('[data-test="responder-legend"]').text()).toContain(
      '90 (45%)'
    );
    expect(wrapper.find('[data-test="responder-legend"]').text()).toContain(
      '110 (55%)'
    );
  });

  it('keeps the monthly table with the share of each month and of the conversations only the AI answered', async () => {
    const wrapper = mountReport();
    await flushPromises();

    const rows = wrapper.findAll('[data-test="month-row"]');
    expect(rows).toHaveLength(2);
    expect(rows[0].text()).toContain('30%');
    expect(rows[0].text()).toContain('20%');
    expect(rows[1].text()).toContain('60%');
    expect(rows[1].text()).toContain('50%');
  });

  it('scales the bars to the busiest month', async () => {
    aiAnalyticsAPI.replies.mockResolvedValue({
      data: report({
        months: [
          { ...report().months[0], ai_replies: 10, human_replies: 10 },
          { ...report().months[1], ai_replies: 50, human_replies: 50 },
        ],
      }),
    });
    const wrapper = mountReport();
    await flushPromises();

    const heights = wrapper
      .findAll('[data-test="month-stack"]')
      .map(bar =>
        parseFloat(bar.attributes('style').match(/height: ([\d.]+)px/)[1])
      );
    expect(heights[1]).toBe(168);
    expect(heights[0]).toBeCloseTo(33.6, 1);
  });

  it('hatches the month in progress and labels it', async () => {
    const wrapper = mountReport();
    await flushPromises();

    const [september, october] = wrapper.findAll('[data-test="month-bar"]');
    expect(october.find('.hatched').exists()).toBe(true);
    expect(october.text()).toContain('em andamento');
    expect(september.find('.hatched').exists()).toBe(false);
  });

  it('puts the percentages in the tooltip of each month', async () => {
    const wrapper = mountReport();
    await flushPromises();

    const tooltip = wrapper.findAll('[data-test="month-tooltip"]')[0].text();
    expect(tooltip).toContain('30 (30%)');
    expect(tooltip).toContain('70 (70%)');
  });

  it('shows a dotted line, not a bar, for a month without replies, and "—" for its share', async () => {
    aiAnalyticsAPI.replies.mockResolvedValue({
      data: report({
        months: [
          {
            month: '2026-09',
            ai_replies: 0,
            human_replies: 0,
            ai_share: 0,
            conversations: { total: 0, ai_only: 0, human_only: 0, mixed: 0 },
            ai_only_share: 0,
          },
          report().months[1],
        ],
      }),
    });
    const wrapper = mountReport();
    await flushPromises();

    expect(wrapper.findAll('[data-test="no-data-month"]')).toHaveLength(1);
    expect(wrapper.findAll('[data-test="month-stack"]')).toHaveLength(1);
    expect(wrapper.findAll('[data-test="month-row"]')[0].text()).toContain('—');
    expect(wrapper.findAll('[data-test="month-row"]')[0].text()).not.toContain(
      '0%'
    );
  });

  it('averages per day: the current month by the days elapsed, the previous one by all its days', async () => {
    const wrapper = mountReport();
    await flushPromises();

    // October (current, 20 days elapsed): 100 replies -> 5 per day. September (30 days): 100 -> 3,3 per day.
    const average = wrapper.find('[data-test="average-per-day"]');
    expect(average.text()).toContain('5 no mês atual');
    expect(average.text()).toContain('3,3 no anterior');
    expect(wrapper.find('[data-test="average-change"]').text()).toContain('▲');
    expect(wrapper.find('[data-test="average-change"]').text()).toContain(
      '50%'
    );
  });

  it('shows ▼ when the current month is slower', async () => {
    aiAnalyticsAPI.replies.mockResolvedValue({
      data: report({
        months: [
          { ...report().months[0], ai_replies: 300, human_replies: 0 },
          { ...report().months[1], ai_replies: 10, human_replies: 0 },
        ],
      }),
    });
    const wrapper = mountReport();
    await flushPromises();

    expect(wrapper.find('[data-test="average-change"]').text()).toContain('▼');
  });

  it('has no change pill when there is nothing to compare with', async () => {
    aiAnalyticsAPI.replies.mockResolvedValue({
      data: report({ months: [report().months[1]] }),
    });
    const wrapper = mountReport();
    await flushPromises();

    expect(wrapper.find('[data-test="average-change"]').exists()).toBe(false);
    expect(wrapper.find('[data-test="average-per-day"]').text()).toContain('—');
  });

  it('keeps the filters behind a button that counts the active ones', async () => {
    const wrapper = mountReport();
    await flushPromises();

    expect(wrapper.find('[data-test="filters-panel"]').exists()).toBe(false);
    expect(wrapper.find('[data-test="filters-button"]').text()).toBe('Filtros');
    await openFilters(wrapper);
    expect(wrapper.find('[data-test="filters-panel"]').exists()).toBe(true);

    await wrapper.findAll('.multi')[1].findAll('button')[0].trigger('click');
    await flushPromises();
    expect(wrapper.find('[data-test="filters-button"]').text()).toBe(
      'Filtros (1)'
    );
  });

  it('reloads when a filter changes, including the AI as who answered', async () => {
    const wrapper = mountReport();
    await flushPromises();
    await openFilters(wrapper);

    await wrapper
      .findAll('.multi')[1]
      .findAll('button')
      .find(button => button.text() === 'IA')
      .trigger('click');
    await flushPromises();

    expect(aiAnalyticsAPI.replies).toHaveBeenLastCalledWith(
      expect.objectContaining({ answered_by: ['ai'] })
    );
  });

  it('offers the owners, the segments and the customers without them', async () => {
    const wrapper = mountReport();
    await flushPromises();
    await openFilters(wrapper);

    const labels = wrapper
      .findAll('.multi button')
      .map(button => button.text());
    expect(labels).toEqual(
      expect.arrayContaining([
        'Brenda',
        'Rodolpho',
        'Sem responsável',
        'Restaurantes',
        'Sem segmento',
      ])
    );
  });

  it('shows "—" instead of 0% when nobody replied, and says so', async () => {
    aiAnalyticsAPI.replies.mockResolvedValue({
      data: report({
        totals: {
          ai_replies: 0,
          human_replies: 0,
          ai_share: 0,
          conversations: 0,
          ai_only_share: 0,
        },
      }),
    });
    const wrapper = mountReport();
    await flushPromises();

    expect(wrapper.text()).toContain('Nenhuma resposta neste período');
    expect(wrapper.find('[data-test="total-share"]').text()).toContain('—');
    expect(wrapper.find('[data-test="total-share"]').text()).not.toContain(
      '0%'
    );
    expect(wrapper.find('[data-test="ai-only-share"]').text()).not.toContain(
      '0%'
    );
    expect(wrapper.findAll('[data-test="month-bar"]')).toHaveLength(0);
  });

  it('keeps the filters reachable while the report reloads', async () => {
    const wrapper = mountReport();
    await flushPromises();
    await openFilters(wrapper);
    aiAnalyticsAPI.replies.mockReturnValue(new Promise(() => {}));

    await wrapper.findAll('.multi')[0].findAll('button')[0].trigger('click');

    expect(wrapper.find('[data-test="filters-panel"]').exists()).toBe(true);
    expect(wrapper.find('[data-test="total-share"]').exists()).toBe(true);
    expect(wrapper.find('[data-test="card-loading"]').exists()).toBe(false);
  });

  it('shows a skeleton the first time', () => {
    aiAnalyticsAPI.replies.mockReturnValue(new Promise(() => {}));
    const wrapper = mountReport();

    expect(wrapper.find('[data-test="card-loading"]').exists()).toBe(true);
  });

  it('shows an error with a retry when the data cannot be loaded', async () => {
    aiAnalyticsAPI.replies.mockRejectedValueOnce(new Error('500'));
    const wrapper = mountReport();
    await flushPromises();

    expect(wrapper.find('[role="alert"]').text()).toContain('Não foi possível');
    await wrapper.find('[data-test="card-error"] button').trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-test="total-share"]').exists()).toBe(true);
  });
});
