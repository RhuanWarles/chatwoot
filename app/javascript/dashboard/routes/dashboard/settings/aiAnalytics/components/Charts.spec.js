import { nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { i18n, timeseries } from '../analyticsFixtures';
import ActivityChart from './ActivityChart.vue';
import ColumnBars from './ColumnBars.vue';
import ShareBar from './ShareBar.vue';
import SparkLine from './SparkLine.vue';

const series = [
  {
    key: 'messages',
    label: 'Mensagens',
    color: 'var(--an-ai)',
    width: 2.5,
    area: true,
  },
  { key: 'turns', label: 'Turnos da IA', color: 'var(--an-turns)', width: 2 },
  {
    key: 'conversations',
    label: 'Conversas',
    color: 'var(--an-conversations)',
    width: 2,
  },
];
const mountChart = (points = timeseries()) =>
  mount(ActivityChart, {
    props: {
      points,
      series,
      totals: { messages: 198, turns: 187, conversations: 28 },
      tokensLabel: 'Total de tokens',
      ariaLabel: 'Atividade da IA por dia',
      locale: 'pt-BR',
    },
    global: { plugins: [i18n()] },
  });
// Without layout in jsdom the chart is 720px wide: the plot starts at 40 and each of the 11 days is 53px apart.
const xOf = index => 40 + index * 53;
// jsdom has no PointerEvent: a mouse event with the pointer event's name reaches the same listeners.
const pointer = (target, type, { clientX = 0, pointerType = 'mouse' } = {}) => {
  const event = new MouseEvent(type, { bubbles: true, clientX });
  Object.defineProperty(event, 'pointerType', { value: pointerType });
  target.element.dispatchEvent(event);
  return nextTick();
};
const tooltip = wrapper =>
  wrapper.find('[data-test="activity-tooltip"]').text();

describe('ActivityChart', () => {
  it('opens with the busiest day selected: its date and its numbers are on screen', () => {
    const wrapper = mountChart();

    expect(tooltip(wrapper)).toContain('05/11/2026');
    expect(tooltip(wrapper)).toContain('Mensagens40');
    expect(tooltip(wrapper)).toContain('Turnos da IA38');
    expect(tooltip(wrapper)).toContain('Conversas6');
    expect(tooltip(wrapper)).toContain('Total de tokens140.000');
  });

  it('follows the pointer and goes back to the busiest day when it leaves', async () => {
    const wrapper = mountChart();
    const svg = wrapper.find('[data-test="activity-chart"]');

    await pointer(svg, 'pointermove', { clientX: xOf(2) });
    expect(tooltip(wrapper)).toContain('03/11/2026');
    expect(tooltip(wrapper)).toContain('Mensagens20');

    await pointer(svg, 'pointerleave', { pointerType: 'mouse' });
    expect(tooltip(wrapper)).toContain('05/11/2026');
  });

  it('keeps the chosen day when a finger is lifted', async () => {
    const wrapper = mountChart();
    const svg = wrapper.find('[data-test="activity-chart"]');

    await pointer(svg, 'pointerdown', { clientX: xOf(8) });
    await pointer(svg, 'pointerleave', { pointerType: 'touch' });

    expect(tooltip(wrapper)).toContain('09/11/2026');
  });

  it('can be explored with the arrow keys, Home, End and Escape', async () => {
    const wrapper = mountChart();
    const region = wrapper.find('[data-test="activity-scroll"]');

    await region.trigger('keydown', { key: 'ArrowRight' });
    expect(tooltip(wrapper)).toContain('06/11/2026');
    await region.trigger('keydown', { key: 'Home' });
    expect(tooltip(wrapper)).toContain('01/11/2026');
    await region.trigger('keydown', { key: 'End' });
    expect(tooltip(wrapper)).toContain('11/11/2026');
    await region.trigger('keydown', { key: 'Escape' });
    expect(tooltip(wrapper)).toContain('05/11/2026');
    expect(region.attributes('tabindex')).toBe('0');
  });

  it('draws the three lines, with the main one thicker', () => {
    const lines = mountChart().findAll('[data-test="series-line"]');

    expect(lines).toHaveLength(3);
    expect(lines.map(line => line.attributes('stroke-width')).sort()).toEqual([
      '2',
      '2',
      '2.5',
    ]);
  });

  it('labels the end of every line with its name and value', () => {
    const labels = mountChart()
      .findAll('[data-test="end-label"]')
      .map(label => label.text());

    expect(labels).toEqual(['Mensagens 31', 'Turnos da IA 29', 'Conversas 3']);
  });

  it('marks only the busiest day and the last day with dots', () => {
    const wrapper = mountChart();

    expect(wrapper.findAll('[data-test="peak-dot"]')).toHaveLength(1);
    expect(wrapper.findAll('[data-test="last-dot"]')).toHaveLength(3);
  });

  it('only labels the vertical axis with whole numbers, and draws subtle gridlines', () => {
    const wrapper = mountChart();
    const ticks = wrapper
      .findAll('[data-test="y-label"]')
      .map(label => label.text());

    expect(ticks.length).toBeGreaterThan(1);
    expect(ticks.every(tick => /^\d+$/.test(tick.replace(/\./g, '')))).toBe(
      true
    );
    expect(wrapper.findAll('[data-test="gridline"]')).toHaveLength(
      ticks.length
    );
  });

  it('shows the totals of the period in the legend', () => {
    const legend = mountChart().find('[data-test="activity-legend"]').text();

    expect(legend).toMatch(/Mensagens\s*198/);
    expect(legend).toMatch(/Turnos da IA\s*187/);
    expect(legend).toMatch(/Conversas\s*28/);
  });

  it('has an accessible name and a summary for screen readers', () => {
    const svg = mountChart().find('[data-test="activity-chart"]');

    expect(svg.attributes('role')).toBe('img');
    expect(svg.attributes('aria-label')).toContain('Atividade da IA por dia');
    expect(svg.attributes('aria-label')).toContain('Mensagens: 198');
  });

  it('scrolls inside its own box instead of squeezing on a narrow screen', () => {
    const wrapper = mountChart();

    expect(wrapper.find('[data-test="activity-scroll"]').classes()).toContain(
      'overflow-x-auto'
    );
    expect(
      Number(wrapper.find('[data-test="activity-chart"]').attributes('width'))
    ).toBeGreaterThanOrEqual(560);
  });

  it('copes with a single day', () => {
    const wrapper = mountChart([timeseries()[4]]);

    expect(tooltip(wrapper)).toContain('05/11/2026');
    expect(wrapper.findAll('[data-test="series-line"]')).toHaveLength(3);
  });
});

describe('ColumnBars', () => {
  const points = [
    { date: '2026-11-01', value: 60000 },
    { date: '2026-11-02', value: 0 },
    { date: '2026-11-03', value: 140000 },
    { date: '2026-11-04', value: 95000 },
  ];
  const mountBars = () =>
    mount(ColumnBars, {
      props: {
        points,
        color: 'var(--an-tokens)',
        ariaLabel: 'Tokens por dia',
        valueLabel: 'tokens',
        locale: 'pt-BR',
      },
    });

  it('shows the busiest day at full strength with its value, the others softer', () => {
    const columns = mountBars().findAll('[data-test="column"]');

    expect(columns).toHaveLength(3);
    expect(columns.map(column => column.attributes('fill-opacity'))).toEqual([
      '0.55',
      '1',
      '0.55',
    ]);
    expect(columns.map(column => column.attributes('data-peak'))).toEqual([
      'false',
      'true',
      'false',
    ]);
  });

  it('writes the value only above the busiest day', () => {
    const values = mountBars().findAll('[data-test="column-value"]');

    expect(values).toHaveLength(1);
    expect(values[0].text()).toBe('140 mil');
  });

  it('draws a dashed tick, not a bar, for a day with nothing', () => {
    const wrapper = mountBars();

    expect(wrapper.findAll('[data-test="empty-tick"]')).toHaveLength(1);
    expect(
      wrapper.find('[data-test="empty-tick"]').attributes('stroke-dasharray')
    ).toBeTruthy();
  });

  it('names each day for hover and for screen readers', () => {
    const wrapper = mountBars();

    expect(wrapper.find('title').text()).toBe('01/11/2026: 60.000 tokens');
    expect(wrapper.find('svg').attributes('role')).toBe('img');
    expect(wrapper.find('svg').attributes('aria-label')).toBe('Tokens por dia');
  });
});

describe('SparkLine', () => {
  it('draws a line and a gradient area for a series, 160x44', () => {
    const wrapper = mount(SparkLine, {
      props: {
        values: [1, 3, 2, 5],
        color: 'var(--an-ai)',
        label: 'Mensagens',
      },
    });
    const svg = wrapper.find('[data-test="sparkline"]');

    expect(svg.attributes('width')).toBe('160');
    expect(svg.attributes('height')).toBe('44');
    expect(svg.attributes('aria-label')).toBe('Mensagens');
    expect(wrapper.findAll('path')).toHaveLength(2);
    expect(wrapper.find('linearGradient').exists()).toBe(true);
  });

  it('stays flat when every value is zero and does not break with no values', () => {
    const flat = mount(SparkLine, {
      props: { values: [0, 0, 0], color: 'var(--an-ai)', label: 'x' },
    });
    expect(flat.find('path[fill="none"]').attributes('d')).toMatch(
      /^M0 41 L80 41 L160 41$/
    );

    const none = mount(SparkLine, {
      props: { values: [], color: 'var(--an-ai)', label: 'x' },
    });
    expect(none.findAll('path')).toHaveLength(0);
  });
});

describe('ShareBar', () => {
  const mountBar = segments =>
    mount(ShareBar, {
      props: { segments, ariaLabel: 'Desfecho', locale: 'pt-BR' },
    });

  it('shows the count and the share of each part', () => {
    const wrapper = mountBar([
      { key: 'a', label: 'Sem transferência', value: 27, color: 'green' },
      { key: 'b', label: 'Transferidas', value: 1, color: 'violet' },
    ]);
    const items = wrapper
      .findAll('[data-test="share-item"]')
      .map(item => item.text());

    expect(items[0]).toContain('27');
    expect(items[0]).toContain('96,4%');
    expect(items[1]).toContain('3,6%');
    expect(wrapper.find('[role="img"]').attributes('aria-label')).toContain(
      'Transferidas: 1 (3,6%)'
    );
  });

  it('draws no segment for a part that is zero', () => {
    const wrapper = mountBar([
      { key: 'a', label: 'A', value: 5, color: 'green' },
      { key: 'b', label: 'B', value: 0, color: 'violet' },
    ]);
    const parts = wrapper.findAll('[data-test="share-segment"]');

    expect(parts[1].attributes('style')).toContain('display: none');
  });

  it('shows dashes, not 0%, when there is nothing to split', () => {
    const wrapper = mountBar([
      { key: 'a', label: 'A', value: 0, color: 'green' },
      { key: 'b', label: 'B', value: 0, color: 'violet' },
    ]);

    wrapper.findAll('[data-test="share-item"]').forEach(item => {
      expect(item.text()).toContain('—');
      expect(item.text()).not.toContain('0%');
    });
  });
});
