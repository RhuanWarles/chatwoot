import { flushPromises, mount } from '@vue/test-utils';

import aiAnalyticsAPI from 'dashboard/api/aiAnalytics';
import { analyticsPayload, emptyPayload, i18n } from './analyticsFixtures';
import { downloadCsv } from './analyticsCsv';
import Analytics from './Analytics.vue';

vi.mock('dashboard/api/aiAnalytics', () => ({
  default: { show: vi.fn(), replies: vi.fn() },
}));
vi.mock('shared/composables/useLocale', () => ({
  useLocale: () => ({ resolvedLocale: { value: 'pt-BR' } }),
}));
vi.mock('./analyticsCsv', async importOriginal => ({
  ...(await importOriginal()),
  downloadCsv: vi.fn(),
}));

const Select = {
  props: ['modelValue', 'options', 'ariaLabel'],
  emits: ['update:modelValue'],
  template:
    '<select :aria-label="ariaLabel" :value="modelValue" @change="$emit(\'update:modelValue\', $event.target.value)"><option v-for="option in options" :key="option.value" :value="option.value">{{ option.label }}</option></select>',
};

const mountPage = async () => {
  const wrapper = mount(Analytics, {
    global: {
      plugins: [i18n()],
      stubs: { Select, ResponderComparison: true },
    },
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
  vi.setSystemTime(new Date(2026, 10, 11, 14, 5));
  aiAnalyticsAPI.show.mockResolvedValue({ data: analyticsPayload() });
});
afterEach(() => {
  vi.useRealTimers();
});

describe('loading', () => {
  it('asks for the last 7 days and shows skeletons until the answer arrives', async () => {
    let answer;
    aiAnalyticsAPI.show.mockReturnValue(
      new Promise(resolve => {
        answer = resolve;
      })
    );
    const wrapper = mount(Analytics, {
      global: {
        plugins: [i18n()],
        stubs: { Select, ResponderComparison: true },
      },
    });
    await flushPromises();

    expect(aiAnalyticsAPI.show).toHaveBeenCalledWith({
      period: '7d',
      ai_agent_id: '',
      inbox_id: '',
    });
    expect(wrapper.findAll('[data-test="kpi-loading"]')).toHaveLength(4);
    expect(
      wrapper.findAll('[data-test="card-loading"]').length
    ).toBeGreaterThan(3);

    answer({ data: analyticsPayload() });
    await flushPromises();
    expect(wrapper.findAll('[data-test="kpi-loading"]')).toHaveLength(0);
    expect(value(wrapper, 'conversations')).toBe('28');
  });

  it('says when the data was fetched', async () => {
    const wrapper = await mountPage();

    expect(wrapper.find('[data-test="updated-at"]').text()).toBe(
      'Atualizado às 14:05'
    );
  });

  it('shows the interval of the period under the selector and on every block', async () => {
    const wrapper = await mountPage();

    expect(wrapper.find('[data-test="period-interval"]').text()).toBe(
      'Últimos 7 dias · 01/11 a 11/11'
    );
    expect(
      wrapper
        .find('[data-test="activity-card"] [data-test="card-period"]')
        .text()
    ).toBe('Últimos 7 dias · 01/11 a 11/11');
    expect(
      wrapper
        .find('[data-test="detail-card"] [data-test="card-period"]')
        .exists()
    ).toBe(true);
  });
});

describe('the four numbers', () => {
  it('shows each number with its context line', async () => {
    const wrapper = await mountPage();

    expect(value(wrapper, 'conversations')).toBe('28');
    expect(context(wrapper, 'conversations')).toBe('média de 2,5 por dia');
    expect(value(wrapper, 'messages')).toBe('198');
    expect(context(wrapper, 'messages')).toBe('pico de 40 em 05/11');
    expect(value(wrapper, 'handoffs')).toBe('1');
    expect(context(wrapper, 'handoffs')).toBe('3,6% das 28 conversas');
    expect(value(wrapper, 'tokens')).toBe('842.034');
    expect(context(wrapper, 'tokens')).toBe('custo ≈ US$ 1,73');
  });

  it('draws a sparkline for three of them and a thin bar for the handoffs', async () => {
    const wrapper = await mountPage();

    ['conversations', 'messages', 'tokens'].forEach(name => {
      expect(kpi(wrapper, name).find('[data-test="sparkline"]').exists()).toBe(
        true
      );
    });
    expect(
      kpi(wrapper, 'handoffs').find('[data-test="sparkline"]').exists()
    ).toBe(false);
    expect(
      kpi(wrapper, 'handoffs').find('[data-test="kpi-bar"]').exists()
    ).toBe(true);
  });

  it('explains what each number counts, including the bot replies it leaves out', async () => {
    const wrapper = await mountPage();
    const info = name =>
      kpi(wrapper, name)
        .find('[data-test="info-tip"]')
        .attributes('aria-label');

    expect(info('conversations')).toContain('pelo menos uma resposta');
    expect(info('messages')).toContain('uma só vez em Turnos da IA');
    expect(info('messages')).toContain('12 respostas de outros bots');
    expect(info('handoffs')).toContain('só pela IA');
  });

  it('leaves the bot sentence out when there is no difference to explain', async () => {
    const payload = analyticsPayload();
    payload.summary.other_bot_messages = 0;
    aiAnalyticsAPI.show.mockResolvedValue({ data: payload });
    const wrapper = await mountPage();

    expect(
      kpi(wrapper, 'messages')
        .find('[data-test="info-tip"]')
        .attributes('aria-label')
    ).not.toContain('outros bots');
  });

  it('has no context to give for a period with nothing in it, and never writes 0%', async () => {
    aiAnalyticsAPI.show.mockResolvedValue({ data: emptyPayload() });
    const wrapper = await mountPage();

    expect(value(wrapper, 'conversations')).toBe('0');
    expect(context(wrapper, 'conversations')).toBe('—');
    expect(context(wrapper, 'messages')).toBe('—');
    expect(context(wrapper, 'handoffs')).toBe('—');
    expect(context(wrapper, 'tokens')).toBe('—');
    expect(wrapper.text()).not.toMatch(/(^|[^\d,.])0%/);
  });
});

describe('activity over time', () => {
  it('opens at the busiest day with its numbers on screen', async () => {
    const wrapper = await mountPage();
    const tip = wrapper.find('[data-test="activity-tooltip"]').text();

    expect(tip).toContain('05/11/2026');
    expect(tip).toContain('40');
  });

  it('shows the empty message instead of a flat chart when nothing happened', async () => {
    aiAnalyticsAPI.show.mockResolvedValue({ data: emptyPayload() });
    const wrapper = await mountPage();

    expect(
      wrapper
        .find('[data-test="activity-card"] [data-test="card-empty"]')
        .exists()
    ).toBe(true);
    expect(wrapper.find('[data-test="activity-chart"]').exists()).toBe(false);
  });

  it('no longer has the separate panel with the date and the three numbers', async () => {
    const wrapper = await mountPage();

    expect(wrapper.find('[data-test="activity-card"] dl.grid').exists()).toBe(
      false
    );
  });
});

describe('filters', () => {
  it('reloads with the chosen agent and inbox', async () => {
    const wrapper = await mountPage();
    const selects = wrapper.findAll('[data-test="filters"] select');

    await selects[1].setValue('1');
    await flushPromises();
    expect(aiAnalyticsAPI.show).toHaveBeenLastCalledWith({
      period: '7d',
      ai_agent_id: '1',
      inbox_id: '',
    });

    await selects[2].setValue('5');
    await flushPromises();
    expect(aiAnalyticsAPI.show).toHaveBeenLastCalledWith({
      period: '7d',
      ai_agent_id: '1',
      inbox_id: '5',
    });
  });

  it('keeps today, 7 days, 30 days, this month and custom as periods', async () => {
    const wrapper = await mountPage();
    const options = wrapper
      .findAll('[data-test="period-select"] option')
      .map(option => option.text());

    expect(options).toEqual([
      'Hoje',
      'Últimos 7 dias',
      'Últimos 30 dias',
      'Este mês',
      'Personalizado',
    ]);
  });

  it('sends a custom period as whole UTC days, the same days the table is made of', async () => {
    const wrapper = await mountPage();
    await wrapper.find('[data-test="period-select"]').setValue('custom');
    expect(aiAnalyticsAPI.show).toHaveBeenCalledTimes(1);

    const [from, to] = wrapper.findAll('[data-test="custom-range"] input');
    await from.setValue('2026-11-01');
    await to.setValue('2026-11-11');
    await wrapper.find('[data-test="custom-range"] button').trigger('click');
    await flushPromises();

    expect(aiAnalyticsAPI.show).toHaveBeenLastCalledWith({
      period: 'custom',
      ai_agent_id: '',
      inbox_id: '',
      start_at: '2026-11-01T00:00:00.000Z',
      end_at: '2026-11-11T23:59:59.999Z',
    });
    expect(wrapper.find('[data-test="period-interval"]').text()).toBe(
      'Personalizado · 01/11 a 11/11'
    );
  });

  it('does not ask for a custom period with the end before the start', async () => {
    const wrapper = await mountPage();
    await wrapper.find('[data-test="period-select"]').setValue('custom');
    const [from, to] = wrapper.findAll('[data-test="custom-range"] input');
    await from.setValue('2026-11-10');
    await to.setValue('2026-11-01');

    expect(
      wrapper.find('[data-test="custom-range"] button').attributes('disabled')
    ).toBeDefined();
  });
});

describe('export', () => {
  it("downloads the detailed table, with the filters in use, as a file named with today's date", async () => {
    const wrapper = await mountPage();

    await wrapper.find('[data-test="export-csv"]').trigger('click');

    expect(downloadCsv).toHaveBeenCalledTimes(1);
    const [content, filename] = downloadCsv.mock.calls[0];
    const lines = content.split('\r\n');
    expect(filename).toBe('analytics-ia-2026-11-11.csv');
    expect(content.startsWith('﻿')).toBe(true);
    expect(lines[0]).toBe(
      '﻿Data;Conversas atendidas;Turnos da IA;Mensagens enviadas;Total de tokens'
    );
    expect(lines[1]).toBe('11/11/2026;3;29;31;77000');
    expect(lines[11]).toBe('01/11/2026;2;11;12;60000');
    expect(lines[12]).toBe('Total (conversas únicas);28;187;198;842034');
  });

  it('cannot export before there is data', async () => {
    aiAnalyticsAPI.show.mockReturnValue(new Promise(() => {}));
    const wrapper = mount(Analytics, {
      global: {
        plugins: [i18n()],
        stubs: { Select, ResponderComparison: true },
      },
    });
    await flushPromises();

    expect(
      wrapper.find('[data-test="export-csv"]').attributes('disabled')
    ).toBeDefined();
  });
});

describe('failure', () => {
  it('shows an error with a retry on each block, and dashes in the numbers', async () => {
    aiAnalyticsAPI.show.mockRejectedValueOnce(new Error('500'));
    const wrapper = await mountPage();

    expect(wrapper.findAll('[data-test="card-error"]').length).toBeGreaterThan(
      3
    );
    expect(value(wrapper, 'conversations')).toBe('—');

    await wrapper.find('[data-test="card-error"] button').trigger('click');
    await flushPromises();

    expect(wrapper.findAll('[data-test="card-error"]')).toHaveLength(0);
    expect(value(wrapper, 'conversations')).toBe('28');
  });

  it('ignores a slow answer that arrives after a newer one', async () => {
    let first;
    aiAnalyticsAPI.show.mockReturnValueOnce(
      new Promise(resolve => {
        first = resolve;
      })
    );
    const wrapper = mount(Analytics, {
      global: {
        plugins: [i18n()],
        stubs: { Select, ResponderComparison: true },
      },
    });
    await flushPromises();
    const newer = analyticsPayload();
    newer.summary.conversations = 5;
    aiAnalyticsAPI.show.mockResolvedValueOnce({ data: newer });
    await wrapper.findAll('[data-test="filters"] select')[0].setValue('30d');
    await flushPromises();

    first({ data: analyticsPayload() });
    await flushPromises();

    expect(value(wrapper, 'conversations')).toBe('5');
  });
});
