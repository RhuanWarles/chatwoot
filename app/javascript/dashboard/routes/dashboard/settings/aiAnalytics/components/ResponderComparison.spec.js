import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';

import aiAnalyticsAPI from 'dashboard/api/aiAnalytics';
import messages from 'dashboard/i18n/locale/pt_BR/crm.json';
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
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: { Select, TagMultiSelectComboBox },
    },
  });

beforeEach(() => {
  vi.clearAllMocks();
  aiAnalyticsAPI.replies.mockResolvedValue({ data: report() });
});

describe('ResponderComparison', () => {
  it('asks for the last 6 months with no filter', async () => {
    mountReport();
    await flushPromises();

    expect(aiAnalyticsAPI.replies).toHaveBeenCalledWith({
      months: 6,
      owner_ids: [],
      answered_by: [],
      segment_ids: [],
    });
  });

  it('shows the AI share of every month and the totals', async () => {
    const wrapper = mountReport();
    await flushPromises();

    const rows = wrapper.findAll('[data-test="month-row"]');
    expect(rows).toHaveLength(2);
    expect(rows[0].text()).toContain('30');
    expect(rows[1].text()).toContain('60%');
    expect(wrapper.findAll('[data-test="month-bar"]')).toHaveLength(2);
    expect(wrapper.find('[data-test="total-share"]').text()).toBe('45%');
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
      .findAll('[data-test="month-bar"] .rounded-t')
      .map(bar => bar.attributes('style'));
    expect(heights[0]).toContain('height: 20%');
    expect(heights[1]).toContain('height: 100%');
  });

  it('reloads when a filter changes, including the AI as who answered', async () => {
    const wrapper = mountReport();
    await flushPromises();

    const answeredBy = wrapper.findAll('.multi')[1];
    await answeredBy
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

  it('says so when nobody replied in the period', async () => {
    aiAnalyticsAPI.replies.mockResolvedValue({
      data: report({
        totals: {
          ai_replies: 0,
          human_replies: 0,
          ai_share: 0,
          ai_only_share: 0,
        },
      }),
    });
    const wrapper = mountReport();
    await flushPromises();

    expect(wrapper.text()).toContain('Nenhuma resposta neste período');
    expect(wrapper.findAll('[data-test="month-bar"]')).toHaveLength(0);
  });

  it('shows an error when the data cannot be loaded', async () => {
    aiAnalyticsAPI.replies.mockRejectedValue(new Error('500'));
    const wrapper = mountReport();
    await flushPromises();

    expect(wrapper.find('[role="alert"]').text()).toContain(
      'Não foi possível carregar'
    );
  });
});
