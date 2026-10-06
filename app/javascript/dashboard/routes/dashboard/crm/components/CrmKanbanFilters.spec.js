import { config, mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { nextTick } from 'vue';
import CrmDeals from '../pages/CrmDeals.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import { pipelinesAPI, dealsAPI } from 'dashboard/api/crm';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';

vi.mock('dashboard/api/crm', () => ({
  pipelinesAPI: { get: vi.fn() },
  dealsAPI: { get: vi.fn(), create: vi.fn(), update: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' }, query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));
config.global.plugins = [
  createI18n({ legacy: false, locale: 'pt_BR', messages: { pt_BR: pt } }),
];
config.global.stubs.CrmContactPicker = true;
const DraggableStub = {
  name: 'Draggable',
  props: ['modelValue'],
  emits: ['change'],
  template:
    '<div><slot v-for="item in modelValue" name="item" :element="item" /></div>',
};
config.global.stubs.Draggable = DraggableStub;
config.global.stubs.RouterLink = { template: '<a><slot /></a>' };

const PIPELINES = [
  {
    id: 1,
    name: 'Commercial',
    active: true,
    stages: [
      { id: 10, name: 'Lead' },
      { id: 20, name: 'Proposal' },
    ],
  },
  {
    id: 2,
    name: 'Other',
    active: true,
    stages: [{ id: 30, name: 'Other stage' }],
  },
];
const BASE_DEALS = [
  {
    id: 1,
    name: 'A',
    status: 'open',
    value: '5000.00',
    pipeline_id: 1,
    pipeline_stage_id: 10,
  },
  {
    id: 2,
    name: 'B',
    status: 'open',
    value: '2000.00',
    pipeline_id: 1,
    pipeline_stage_id: 10,
  },
  {
    id: 3,
    name: 'C',
    status: 'won',
    value: '3000.00',
    pipeline_id: 1,
    pipeline_stage_id: 10,
  },
  {
    id: 4,
    name: 'D',
    status: 'lost',
    value: '4500.00',
    pipeline_id: 1,
    pipeline_stage_id: 10,
  },
  {
    id: 5,
    name: 'E',
    status: 'open',
    value: null,
    pipeline_id: 1,
    pipeline_stage_id: 20,
  },
  {
    id: 6,
    name: 'F',
    status: 'won',
    value: 0,
    pipeline_id: 1,
    pipeline_stage_id: 20,
  },
  {
    id: 7,
    name: 'G',
    status: 'lost',
    value: '12500.50',
    pipeline_id: 1,
    pipeline_stage_id: 20,
  },
  {
    id: 8,
    name: 'H',
    status: 'won',
    value: '800.00',
    pipeline_id: 2,
    pipeline_stage_id: 30,
  },
];
let records;
beforeEach(() => {
  records = structuredClone(BASE_DEALS);
  pipelinesAPI.get.mockResolvedValue({ data: PIPELINES });
  dealsAPI.get.mockImplementation(async () => ({
    data: records.map(deal => ({ ...deal })),
  }));
  dealsAPI.update.mockImplementation(async (id, { deal }) => {
    Object.assign(
      records.find(record => record.id === id),
      deal
    );
    return { data: records.find(record => record.id === id) };
  });
  dealsAPI.create.mockImplementation(async ({ deal }) => {
    const record = { id: 50, status: 'open', ...deal };
    records.push(record);
    return { data: record };
  });
});

describe('Kanban status filters and stage totals', () => {
  it('starts with only Todos pressed and renders pipeline-scoped totals', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    const filters = wrapper.find('[role="group"]');
    const active = filters.findAll('button[aria-pressed="true"]');
    expect(active.map(button => button.text())).toEqual(['Todos']);
    const columns = wrapper.findAll('section > .w-72');
    expect(columns[0].text()).toContain('4 negócios');
    expect(columns[0].find('p').text().replace(/\s/g, ' ')).toBe(
      'R$ 14.500,00'
    );
    expect(columns[1].text()).toContain('3 negócios');
    expect(columns[1].find('p').text().replace(/\s/g, ' ')).toBe(
      'R$ 12.500,50'
    );
    expect(wrapper.findAll('article')).toHaveLength(7);
    wrapper.unmount();
  });

  it.each([
    [['Em andamento'], 2, 'R$ 7.000,00'],
    [['Ganhos'], 1, 'R$ 3.000,00'],
    [['Perdidos'], 1, 'R$ 4.500,00'],
    [['Ganhos', 'Perdidos'], 2, 'R$ 7.500,00'],
    [['Em andamento', 'Ganhos'], 3, 'R$ 10.000,00'],
    [['Em andamento', 'Perdidos'], 3, 'R$ 11.500,00'],
  ])(
    'filters %s and derives both count and amount from the visible deals',
    async (labels, count, total) => {
      const wrapper = mount(CrmDeals);
      await flushPromises();
      const group = wrapper.find('[role="group"]');
      await Promise.all(
        labels.map(label =>
          group
            .findAll('button')
            .find(button => button.text() === label)
            .trigger('click')
        )
      );
      const column = wrapper.findAll('section > .w-72')[0];
      expect(column.findAll('article')).toHaveLength(count);
      expect(column.text()).toContain(
        count === 1 ? '1 negócio' : `${count} negócios`
      );
      expect(column.find('p').text().replace(/\s/g, ' ')).toBe(total);
      expect(
        group
          .findAll('button[aria-pressed="true"]')
          .map(button => button.text())
          .sort()
      ).toEqual([...labels].sort());
      expect(dealsAPI.get).toHaveBeenCalledTimes(1);
      wrapper.unmount();
    }
  );

  it('toggles an individual status off while retaining another active status', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    const group = wrapper.find('[role="group"]');
    await group.findAll('button')[3].trigger('click');
    await group.findAll('button')[2].trigger('click');
    await group.findAll('button')[3].trigger('click');
    expect(
      group.findAll('button[aria-pressed="true"]').map(button => button.text())
    ).toEqual(['Ganhos']);
    expect(
      wrapper.findAll('section > .w-72')[0].findAll('article')
    ).toHaveLength(1);
    wrapper.unmount();
  });

  it('normalizes all three specific statuses into only Todos', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    const group = wrapper.find('[role="group"]');
    await group.findAll('button')[1].trigger('click');
    await group.findAll('button')[2].trigger('click');
    await group.findAll('button')[3].trigger('click');
    expect(
      group.findAll('button[aria-pressed="true"]').map(button => button.text())
    ).toEqual(['Todos']);
    expect(wrapper.findAll('article')).toHaveLength(7);
    wrapper.unmount();
  });

  it('returns to Todos when the last specific filter is removed', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    const group = wrapper.find('[role="group"]');
    await group.findAll('button')[2].trigger('click');
    await group.findAll('button')[2].trigger('click');
    expect(
      group.findAll('button[aria-pressed="true"]').map(button => button.text())
    ).toEqual(['Todos']);
    expect(wrapper.findAll('article')).toHaveLength(7);
    wrapper.unmount();
  });

  it('clears multiple filters through Todos', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    const group = wrapper.find('[role="group"]');
    await group.findAll('button')[2].trigger('click');
    await group.findAll('button')[3].trigger('click');
    await group.findAll('button')[0].trigger('click');
    expect(
      group.findAll('button[aria-pressed="true"]').map(button => button.text())
    ).toEqual(['Todos']);
    expect(wrapper.findAll('article')).toHaveLength(7);
    wrapper.unmount();
  });

  it('sums missing, zero and decimal values without accumulating floating point errors', async () => {
    records.push(
      {
        id: 9,
        name: 'I',
        status: 'open',
        value: '0.10',
        pipeline_id: 1,
        pipeline_stage_id: 20,
      },
      {
        id: 10,
        name: 'J',
        status: 'open',
        value: '0.20',
        pipeline_id: 1,
        pipeline_stage_id: 20,
      }
    );
    const wrapper = mount(CrmDeals);
    await flushPromises();
    const column = wrapper.findAll('section > .w-72')[1];
    expect(column.text()).toContain('5 negócios');
    expect(column.find('p').text().replace(/\s/g, ' ')).toBe('R$ 12.500,80');
    wrapper.unmount();
  });

  it('updates totals immediately on drag, persists only stage, and retains the won status', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await wrapper.find('[role="group"]').findAll('button')[2].trigger('click');
    const draggables = wrapper.findAllComponents(DraggableStub);
    const deal = draggables[0].props('modelValue')[0];
    let confirmMove;
    dealsAPI.update.mockImplementationOnce(
      () =>
        new Promise(resolve => {
          confirmMove = resolve;
        })
    );
    draggables[1].vm.$emit('change', { added: { element: deal } });
    await nextTick();
    const columns = wrapper.findAll('section > .w-72');
    expect(columns[0].find('p').text().replace(/\s/g, ' ')).toBe('R$ 0,00');
    expect(columns[1].find('p').text().replace(/\s/g, ' ')).toBe('R$ 3.000,00');
    expect(deal.status).toBe('won');
    expect(dealsAPI.update).toHaveBeenCalledWith(deal.id, {
      deal: { pipeline_stage_id: 20 },
    });
    confirmMove({ data: {} });
    await flushPromises();
    wrapper.unmount();
  });

  it('restores counts and totals when a stage update fails', async () => {
    const wrapper = mount(CrmDeals, {
      global: { config: { errorHandler: vi.fn() } },
    });
    await flushPromises();
    const draggables = wrapper.findAllComponents(DraggableStub);
    const deal = draggables[0].props('modelValue')[0];
    dealsAPI.update.mockRejectedValueOnce(new Error('offline'));
    draggables[1].vm.$emit('change', { added: { element: deal } });
    await flushPromises();
    const column = wrapper.findAll('section > .w-72')[0];
    expect(column.findAll('article')).toHaveLength(4);
    expect(column.find('p').text().replace(/\s/g, ' ')).toBe('R$ 14.500,00');
    expect(deal.pipeline_stage_id).toBe(10);
    wrapper.unmount();
  });

  it('refreshes totals after an amount edit without a page reload', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await wrapper.find('article button[aria-label]').trigger('click');
    const input = wrapper.find('form input[inputmode="decimal"]');
    await input.trigger('focus');
    await input.setValue('6000,25');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(
      wrapper.findAll('section > .w-72')[0].find('p').text().replace(/\s/g, ' ')
    ).toBe('R$ 15.500,25');
    wrapper.unmount();
  });

  it('removes a deal from active filters after a status edit and recomputes totals', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await wrapper.find('[role="group"]').findAll('button')[1].trigger('click');
    await wrapper.find('article button[aria-label]').trigger('click');
    wrapper
      .findAllComponents(ComboBox)
      .at(-1)
      .vm.$emit('update:modelValue', 'lost');
    await nextTick();
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    const column = wrapper.findAll('section > .w-72')[0];
    expect(column.findAll('article')).toHaveLength(1);
    expect(column.find('p').text().replace(/\s/g, ' ')).toBe('R$ 2.000,00');
    wrapper.unmount();
  });

  it('recomputes visible totals after creating a deal', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await wrapper.find('[role="group"]').findAll('button')[1].trigger('click');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Novo negócio')
      .trigger('click');
    await wrapper.find('form input').setValue('New lead');
    const input = wrapper.find('form input[inputmode="decimal"]');
    await input.trigger('focus');
    await input.setValue('500');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    const column = wrapper.findAll('section > .w-72')[0];
    expect(column.findAll('article')).toHaveLength(3);
    expect(column.find('p').text().replace(/\s/g, ' ')).toBe('R$ 7.500,00');
    wrapper.unmount();
  });

  it('recomputes stage totals on pipeline selection and preserves the active filter', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await wrapper.find('[role="group"]').findAll('button')[2].trigger('click');
    wrapper.findComponent(ComboBox).vm.$emit('update:modelValue', 2);
    await flushPromises();
    const columns = wrapper.findAll('section > .w-72');
    expect(columns).toHaveLength(1);
    expect(columns[0].find('h2').text()).toBe('Other stage');
    expect(columns[0].find('p').text().replace(/\s/g, ' ')).toBe('R$ 800,00');
    expect(columns[0].findAll('article')).toHaveLength(1);
    expect(
      wrapper
        .find('[role="group"]')
        .findAll('button[aria-pressed="true"]')
        .map(button => button.text())
    ).toEqual(['Ganhos']);
    wrapper.unmount();
  });
});

describe('Inactive pipeline selection', () => {
  it('defaults to an active pipeline and disables creation when viewing an inactive one', async () => {
    pipelinesAPI.get.mockResolvedValue({
      data: [{ ...PIPELINES[0], active: false }, PIPELINES[1]],
    });
    const wrapper = mount(CrmDeals);
    await flushPromises();
    const selector = wrapper.findComponent(ComboBox);
    expect(selector.props('modelValue')).toBe(2);
    selector.vm.$emit('update:modelValue', 1);
    await flushPromises();
    const button = wrapper
      .findAll('button')
      .find(item => item.text() === pt.CRM.NEW_DEAL);
    expect(button.attributes('disabled')).toBeDefined();
  });
});
