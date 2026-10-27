import { config, flushPromises, mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';

import { dealsAPI, pipelinesAPI, segmentsAPI } from 'dashboard/api/crm';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';
import CrmDeals from '../pages/CrmDeals.vue';

vi.mock('dashboard/api/crm', () => ({
  pipelinesAPI: { get: vi.fn() },
  dealsAPI: { get: vi.fn(), create: vi.fn(), update: vi.fn() },
  segmentsAPI: { get: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' }, query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

const AGENTS = [
  { id: 7, name: 'Brenda' },
  { id: 8, name: 'Rodolpho' },
];
config.global.plugins = [
  createStore({
    getters: {
      getCurrentRole: () => 'administrator',
      'agents/getAgents': () => AGENTS,
      'labels/getLabels': () => [],
      getUISettings: () => ({}),
    },
    actions: { 'agents/get': () => {} },
  }),
  createI18n({ legacy: false, locale: 'pt_BR', messages: { pt_BR: pt } }),
];
config.global.stubs.CrmContactPicker = true;
config.global.stubs.RouterLink = { template: '<a><slot /></a>' };
config.global.stubs.Draggable = {
  name: 'Draggable',
  props: ['modelValue'],
  template:
    '<div><slot v-for="item in modelValue" name="item" :element="item" /></div>',
};

const PIPELINES = [
  {
    id: 1,
    name: 'Comercial',
    active: true,
    stages: [{ id: 10, name: 'Lead' }],
  },
];
const deal = (id, name, extra) => ({
  id,
  name,
  status: 'open',
  value: '1000.00',
  pipeline_id: 1,
  pipeline_stage_id: 10,
  segment_id: null,
  answered_by: { user_ids: [], ai: false },
  ...extra,
});
const DEALS = [
  deal(1, 'Só IA', { segment_id: 1, answered_by: { user_ids: [], ai: true } }),
  deal(2, 'Só Brenda', {
    segment_id: 1,
    answered_by: { user_ids: [7], ai: false },
  }),
  deal(3, 'IA e Rodolpho', {
    segment_id: 2,
    answered_by: { user_ids: [8], ai: true },
  }),
  deal(4, 'Ninguém respondeu'),
];

const names = wrapper =>
  wrapper.findAll('article').map(article => article.text());
const openFilters = async wrapper => {
  await wrapper
    .findAll('button')
    .find(button => button.text().startsWith('Filtros'))
    .trigger('click');
  await flushPromises();
};
const choose = async (wrapper, label) => {
  const checkbox = wrapper
    .findAll('label')
    .find(item => item.text() === label)
    .find('input');
  await checkbox.setValue(true);
};
const apply = async wrapper => {
  await wrapper
    .findAll('button')
    .find(button => button.text() === 'Aplicar filtros')
    .trigger('click');
  await flushPromises();
};

beforeEach(() => {
  vi.clearAllMocks();
  pipelinesAPI.get.mockResolvedValue({ data: PIPELINES });
  dealsAPI.get.mockResolvedValue({ data: structuredClone(DEALS) });
  segmentsAPI.get.mockResolvedValue({
    data: [
      { id: 1, name: 'Restaurantes', active: true },
      { id: 2, name: 'Clínicas', active: true },
    ],
  });
});

describe('Kanban filter by who answered', () => {
  it('lists the AI and every agent', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await openFilters(wrapper);

    const labels = wrapper.findAll('label').map(item => item.text());
    expect(labels).toEqual(
      expect.arrayContaining(['IA', 'Brenda', 'Rodolpho'])
    );
    wrapper.unmount();
  });

  it('shows the customers answered by any of the selected', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await openFilters(wrapper);
    await choose(wrapper, 'IA');
    await choose(wrapper, 'Brenda');
    await apply(wrapper);

    const shown = names(wrapper).join(' ');
    expect(shown).toContain('Só IA');
    expect(shown).toContain('Só Brenda');
    expect(shown).toContain('IA e Rodolpho');
    expect(shown).not.toContain('Ninguém respondeu');
    wrapper.unmount();
  });

  it('is not the same as the owner: a single person narrows to her customers', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await openFilters(wrapper);
    await choose(wrapper, 'Rodolpho');
    await apply(wrapper);

    expect(wrapper.findAll('article')).toHaveLength(1);
    expect(names(wrapper)[0]).toContain('IA e Rodolpho');
    wrapper.unmount();
  });
});

describe('Kanban filter by segment', () => {
  it('lists the registered segments and the deals without one', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await openFilters(wrapper);

    const labels = wrapper.findAll('label').map(item => item.text());
    expect(labels).toEqual(
      expect.arrayContaining(['Restaurantes', 'Clínicas', 'Sem segmento'])
    );
    wrapper.unmount();
  });

  it('keeps only the deals of the chosen segments', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await openFilters(wrapper);
    await choose(wrapper, 'Restaurantes');
    await apply(wrapper);

    expect(wrapper.findAll('article')).toHaveLength(2);
    expect(names(wrapper).join(' ')).not.toContain('IA e Rodolpho');
    wrapper.unmount();
  });

  it('can show only the deals that have no segment', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await openFilters(wrapper);
    await choose(wrapper, 'Sem segmento');
    await apply(wrapper);

    expect(wrapper.findAll('article')).toHaveLength(1);
    expect(names(wrapper)[0]).toContain('Ninguém respondeu');
    wrapper.unmount();
  });

  it('combines the segment with who answered', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await openFilters(wrapper);
    await choose(wrapper, 'Restaurantes');
    await choose(wrapper, 'IA');
    await apply(wrapper);

    expect(wrapper.findAll('article')).toHaveLength(1);
    expect(names(wrapper)[0]).toContain('Só IA');
    wrapper.unmount();
  });
});
