import { flushPromises, mount } from '@vue/test-utils';
import ActivityLineChart from './ActivityLineChart.vue';

vi.mock('@chatwoot/viz', () => ({
  LineChart: {
    props: ['data', 'onItemClick'],
    template: `
      <svg>
        <g
          v-for="(category, index) in data.categories"
          :key="category"
          class="cw-viz-line__x-tick"
        >
          <line class="cw-viz-line__tick-mark" />
        </g>
      </svg>
    `,
  },
}));

const data = {
  categories: ['19/10', '20/10', '21/10'],
  series: [
    { label: 'Conversas atendidas', color: 'blue', data: [4, 0, 2] },
    { label: 'Turnos da IA', color: 'iris', data: [105, 0, 14] },
    { label: 'Mensagens enviadas', color: 'teal', data: [156, 0, 21] },
  ],
};

const mountChart = async () => {
  global.ResizeObserver = vi.fn(() => ({
    observe: vi.fn(),
    disconnect: vi.fn(),
  }));

  const wrapper = mount(ActivityLineChart, {
    props: {
      data,
      formatValue: value => String(value),
      height: 200,
      width: 300,
    },
  });

  Object.defineProperty(wrapper.element, 'getBoundingClientRect', {
    value: () => ({ left: 0, width: 300 }),
  });

  wrapper.findAll('.cw-viz-line__x-tick').forEach((tick, index) => {
    Object.defineProperty(tick.element, 'getBoundingClientRect', {
      value: () => ({ left: index * 100, width: 0 }),
    });
  });

  await flushPromises();
  return wrapper;
};

const dispatchPointerEvent = (element, type, clientX, clientY) => {
  const event = new PointerEvent(type, { bubbles: true });
  Object.defineProperties(event, {
    clientX: { value: clientX },
    clientY: { value: clientY },
  });
  element.dispatchEvent(event);
};

describe('ActivityLineChart', () => {
  it('selects the nearest date above and below the plotted line', async () => {
    const wrapper = await mountChart();

    dispatchPointerEvent(wrapper.element, 'pointermove', 205, 20);
    await wrapper.vm.$nextTick();
    expect(wrapper.text()).toContain('21/10');
    expect(wrapper.text()).toContain('Conversas atendidas2');
    expect(wrapper.text()).toContain('Turnos da IA14');
    expect(wrapper.text()).toContain('Mensagens enviadas21');

    dispatchPointerEvent(wrapper.element, 'pointermove', 205, 180);
    await wrapper.vm.$nextTick();
    expect(wrapper.text()).toContain('21/10');
  });

  it('selects a date with a click for touch-compatible interaction', async () => {
    const wrapper = await mountChart();

    await wrapper.trigger('click', { clientX: 95, clientY: 100 });

    expect(wrapper.text()).toContain('20/10');
    expect(wrapper.text()).toContain('Conversas atendidas0');
    expect(wrapper.text()).toContain('Turnos da IA0');
    expect(wrapper.text()).toContain('Mensagens enviadas0');
  });
});
