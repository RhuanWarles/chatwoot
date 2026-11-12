import { flushPromises, mount } from '@vue/test-utils';
import generalDashboardAPI from 'dashboard/api/generalDashboard';
import aiAnalyticsAPI from 'dashboard/api/aiAnalytics';
import { i18n } from '../settings/aiAnalytics/analyticsFixtures';
import { dashboardPayload, emptyDashboard } from './dashboardFixtures';
import GeneralDashboard from './GeneralDashboard.vue';

vi.mock('dashboard/api/generalDashboard', () => ({
  default: { show: vi.fn() },
}));
vi.mock('dashboard/api/aiAnalytics', () => ({ default: { replies: vi.fn() } }));
vi.mock('shared/composables/useLocale', () => ({
  useLocale: () => ({ resolvedLocale: { value: 'pt-BR' } }),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: { value: 1 } }),
}));

const Select = {
  props: ['modelValue', 'options', 'ariaLabel'],
  emits: ['update:modelValue'],
  template:
    '<select :aria-label="ariaLabel" :value="modelValue" @change="$emit(\'update:modelValue\', $event.target.value)"><option v-for="option in options" :key="option.value" :value="option.value">{{ option.label }}</option></select>',
};
const RouterLink = {
  props: ['to'],
  template: '<a :data-to="to.name"><slot /></a>',
};

const mountPage = async () => {
  const wrapper = mount(GeneralDashboard, {
    global: { plugins: [i18n()], stubs: { Select, RouterLink } },
  });
  await flushPromises();
  return wrapper;
};
const kpi = (wrapper, name) => wrapper.find(`[data-test="kpi-${name}"]`);
const value = (wrapper, name) =>
  kpi(wrapper, name).find('[data-test="kpi-value"]').text();
const context = (wrapper, name) =>
  kpi(wrapper, name).find('[data-test="kpi-context"]').text();

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date(2026, 10, 12, 14, 5));
  generalDashboardAPI.show.mockResolvedValue({ data: dashboardPayload() });
  aiAnalyticsAPI.replies.mockResolvedValue({
    data: {
      months: [
        {
          month: '2026-10',
          ai_replies: 40,
          human_replies: 100,
          ai_share: 28.57,
          ai_only_share: 10,
          conversations: { total: 5 },
        },
      ],
    },
  });
});
afterEach(() => {
  vi.useRealTimers();
});

describe('loading', () => {
  it('asks for the last 7 days with no filter, and shows the zone and the time of the answer', async () => {
    const wrapper = await mountPage();

    expect(generalDashboardAPI.show).toHaveBeenCalledWith({
      period: '7d',
      inbox_id: '',
      pipeline_id: '',
    });
    expect(wrapper.find('[data-test="timezone"]').text()).toBe(
      'Fuso: America/Sao_Paulo'
    );
    expect(wrapper.find('[data-test="updated-at"]').text()).toBe(
      'Atualizado às 14:05'
    );
    expect(wrapper.find('[data-test="period-interval"]').text()).toBe(
      'Últimos 7 dias · 06/11 a 12/11'
    );
  });

  it('shows skeletons until the answer arrives', async () => {
    generalDashboardAPI.show.mockReturnValue(new Promise(() => {}));
    const wrapper = mount(GeneralDashboard, {
      global: { plugins: [i18n()], stubs: { Select, RouterLink } },
    });
    await flushPromises();

    expect(wrapper.findAll('[data-test="kpi-loading"]')).toHaveLength(8);
  });

  it('shows an error on each block with a retry, and loads again', async () => {
    generalDashboardAPI.show.mockRejectedValueOnce(new Error('500'));
    const wrapper = await mountPage();

    expect(wrapper.findAll('[data-test="card-error"]').length).toBeGreaterThan(
      4
    );
    await wrapper.find('[data-test="card-error"] button').trigger('click');
    await flushPromises();

    expect(wrapper.findAll('[data-test="card-error"]')).toHaveLength(0);
    expect(value(wrapper, 'activity')).toBe('312');
  });
});

describe('the eight numbers', () => {
  it('shows each number with its context', async () => {
    const wrapper = await mountPage();

    expect(value(wrapper, 'activity')).toBe('312');
    expect(context(wrapper, 'activity')).toBe(
      '↑ 12% em relação ao período anterior'
    );
    expect(value(wrapper, 'waiting')).toBe('7');
    expect(context(wrapper, 'waiting')).toBe('a mais antiga espera há 42 min');
    expect(value(wrapper, 'first-response')).toBe('3 min 12 s');
    expect(context(wrapper, 'first-response')).toBe(
      'mediana 2 min 40 s · ↓ 18% em relação ao período anterior'
    );
    expect(value(wrapper, 'ai-only')).toBe('64%');
    expect(context(wrapper, 'ai-only')).toBe(
      '192 de 300 conversas respondidas'
    );
  });

  it('shows the AI, the cost, the deals and the broadcasts', async () => {
    const wrapper = await mountPage();

    expect(value(wrapper, 'handoffs')).toBe('18');
    expect(context(wrapper, 'handoffs')).toBe('9% das conversas da IA');
    expect(value(wrapper, 'cost')).toBe('< US$ 0,01');
    expect(context(wrapper, 'cost')).toBe('total estimado ≈ US$ 1,73');
    expect(value(wrapper, 'won')).toBe('14');
    expect(context(wrapper, 'won').replace(/\s/g, ' ')).toContain(
      'R$ 86.400,00'
    );
    expect(value(wrapper, 'blasts')).toBe('1.280');
    expect(context(wrapper, 'blasts')).toBe('28% responderam');
  });

  it('says nothing, never 0 or 0%, when there is nothing to say', async () => {
    generalDashboardAPI.show.mockResolvedValue({ data: emptyDashboard() });
    const wrapper = await mountPage();

    expect(value(wrapper, 'first-response')).toBe('—');
    expect(value(wrapper, 'ai-only')).toBe('—');
    expect(value(wrapper, 'handoffs')).toBe('—');
    expect(value(wrapper, 'cost')).toBe('—');
    expect(value(wrapper, 'won')).toBe('—');
    expect(value(wrapper, 'blasts')).toBe('—');
    expect(context(wrapper, 'waiting')).toBe(
      'Ninguém esperando. Tudo respondido.'
    );
    expect(wrapper.text()).not.toMatch(/(^|[^\d,.])0%/);
  });
});

describe('filters', () => {
  it('reloads with the chosen inbox', async () => {
    const wrapper = await mountPage();

    await wrapper.find('[data-test="inbox-select"]').setValue('5');
    await flushPromises();

    expect(generalDashboardAPI.show).toHaveBeenLastCalledWith({
      period: '7d',
      inbox_id: '5',
      pipeline_id: '',
    });
  });

  it('sends a custom period as whole days of the account', async () => {
    const wrapper = await mountPage();
    await wrapper.find('[data-test="period-select"]').setValue('custom');
    const [from, to] = wrapper.findAll('[data-test="custom-range"] input');
    await from.setValue('2026-11-01');
    await to.setValue('2026-11-05');
    await wrapper.find('[data-test="custom-range"] button').trigger('click');
    await flushPromises();

    expect(generalDashboardAPI.show).toHaveBeenLastCalledWith({
      period: 'custom',
      inbox_id: '',
      pipeline_id: '',
      start_date: '2026-11-01',
      end_date: '2026-11-05',
    });
  });
});

describe('the blocks', () => {
  it('has the blocks of the example, each saying its period', async () => {
    const wrapper = await mountPage();

    ['replies', 'waiting', 'heatmap', 'ai', 'team', 'crm', 'blasts'].forEach(
      name => {
        expect(wrapper.find(`[data-test="${name}-card"]`).exists()).toBe(true);
      }
    );
    expect(
      wrapper
        .find('[data-test="replies-card"] [data-test="card-period"]')
        .text()
    ).toBe('Últimos 7 dias · 06/11 a 12/11');
    expect(
      wrapper
        .find('[data-test="waiting-card"] [data-test="card-period"]')
        .text()
    ).toBe('Agora');
  });

  it('links each block to its full report', async () => {
    const wrapper = await mountPage();
    const links = wrapper
      .findAll('[data-test="full-report"]')
      .map(link => link.attributes('data-to'));

    expect(links).toEqual(
      expect.arrayContaining([
        'conversation_reports',
        'agent_reports_index',
        'crm_deals',
        'ai_analytics_settings',
        'campaigns_whatsapp_index',
      ])
    );
  });

  it('draws the replies of each day, the waiting customers and the people of the team', async () => {
    const wrapper = await mountPage();

    expect(wrapper.findAll('[data-test="reply-bar"]')).toHaveLength(7);
    expect(wrapper.find('[data-test="replies-legend"]').text()).toContain(
      '263 (67%)'
    );
    expect(wrapper.findAll('[data-test="waiting-item"]')).toHaveLength(3);
    expect(wrapper.findAll('[data-test="agent-row"]')).toHaveLength(2);
  });

  it('marks a customer waiting half an hour or more', async () => {
    const wrapper = await mountPage();
    const longs = wrapper.findAll(
      '[data-test="waiting-item"] [data-long="true"]'
    );

    expect(longs).toHaveLength(2);
  });

  it('shows empty blocks instead of flat charts when nothing happened', async () => {
    generalDashboardAPI.show.mockResolvedValue({ data: emptyDashboard() });
    const wrapper = await mountPage();

    expect(
      wrapper
        .find('[data-test="replies-card"] [data-test="card-empty"]')
        .exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-test="team-card"] [data-test="card-empty"]').exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-test="crm-card"] [data-test="card-empty"]').text()
    ).toBe('Nenhum funil ativo no CRM.');
    expect(
      wrapper
        .find('[data-test="blasts-card"] [data-test="card-empty"]')
        .exists()
    ).toBe(true);
    expect(
      wrapper.find('[data-test="ai-card"] [data-test="card-empty"]').text()
    ).toBe('A IA não está ativada nesta conta.');
  });

  it('reloads with another pipeline when it is chosen', async () => {
    generalDashboardAPI.show.mockResolvedValue({
      data: dashboardPayload({
        crm: {
          ...dashboardPayload().crm,
          pipelines: [
            { id: 1, name: 'Comercial' },
            { id: 2, name: 'Pós-venda' },
          ],
        },
      }),
    });
    const wrapper = await mountPage();

    await wrapper.find('[data-test="pipeline-select"]').setValue('2');
    await flushPromises();

    expect(generalDashboardAPI.show).toHaveBeenLastCalledWith(
      expect.objectContaining({ pipeline_id: 2 })
    );
  });

  it('shows the CRM funnel with the deals and the money of each stage, and the won/lost tiles', async () => {
    const wrapper = await mountPage();

    expect(wrapper.findAll('[data-test="funnel-stage"]')).toHaveLength(2);
    expect(wrapper.find('[data-test="tile-win-rate"]').text()).toContain('56%');
    expect(wrapper.find('[data-test="tile-win-rate"]').text()).toContain(
      '14 de 25 fechados'
    );
    expect(wrapper.find('[data-test="lost-reasons"]').text()).toContain(
      'Preço'
    );
  });

  it('shows the monthly AI vs people chart from the AI report, and the AI numbers of the period', async () => {
    const wrapper = await mountPage();

    expect(aiAnalyticsAPI.replies).toHaveBeenCalledWith({ months: 6 });
    expect(
      wrapper.find('[data-test="ai-card"] [data-test="month-bar"]').exists()
    ).toBe(true);
    expect(wrapper.find('[data-test="tile-ai-share"]').text()).toContain('67%');
    expect(wrapper.find('[data-test="tile-ai-only"]').text()).toContain('64%');
    expect(wrapper.find('[data-test="ai-summary"]').text()).toContain(
      '83% de sucesso'
    );
  });
});
