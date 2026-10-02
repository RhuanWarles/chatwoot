import { config, mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import CrmDeals from '../pages/CrmDeals.vue';
import { pipelinesAPI, dealsAPI } from 'dashboard/api/crm';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';
import en from 'dashboard/i18n/locale/en/crm.json';

vi.mock('dashboard/api/crm', () => ({
  pipelinesAPI: { get: vi.fn() },
  dealsAPI: { get: vi.fn(), create: vi.fn(), update: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
}));

config.global.plugins = [
  createI18n({
    legacy: false,
    locale: 'pt_BR',
    messages: { pt_BR: pt, en },
  }),
];
config.global.stubs.CrmContactPicker = true;
config.global.stubs.Draggable = {
  props: ['modelValue'],
  template:
    '<div><slot v-for="item in modelValue" name="item" :element="item" /></div>',
};
config.global.stubs.RouterLink = { template: '<a><slot /></a>' };

const DEALS = [
  {
    id: 1,
    pipeline_id: 1,
    pipeline_stage_id: 10,
    name: 'Won deal',
    status: 'won',
    value: '2500.00',
  },
  {
    id: 2,
    pipeline_id: 1,
    pipeline_stage_id: 10,
    name: 'Lost deal',
    status: 'lost',
    value: 0,
  },
  {
    id: 3,
    pipeline_id: 1,
    pipeline_stage_id: 10,
    name: 'Open deal',
    status: 'open',
    value: null,
  },
];

beforeEach(() => {
  pipelinesAPI.get.mockResolvedValue({
    data: [{ id: 1, name: 'Sales', stages: [{ id: 10, name: 'Lead' }] }],
  });
  dealsAPI.get.mockResolvedValue({ data: DEALS });
});

describe('CRM cards and translations', () => {
  it('renders formatted BRL, preserves zero and omits an absent amount', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    const cards = wrapper.findAll('article');
    expect(cards[0].text().replace(/\s/g, ' ')).toContain('R$ 2.500,00');
    expect(cards[1].text().replace(/\s/g, ' ')).toContain('R$ 0,00');
    expect(cards[2].text()).not.toContain('R$');
    wrapper.unmount();
  });

  it('shows localized won/lost badges with the existing theme colors', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    const cards = wrapper.findAll('article');
    expect(cards[0].find('.bg-n-teal-3').text()).toBe('Ganho');
    expect(cards[1].find('.bg-n-ruby-3').text()).toBe('Perdido');
    expect(cards[2].find('.bg-n-teal-3').exists()).toBe(false);
    expect(cards[2].find('.bg-n-ruby-3').exists()).toBe(false);
    wrapper.unmount();
  });

  it('renders a visible Status label above the edit select', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await wrapper.find('article').trigger('click');
    const labels = wrapper.find('form').findAll('span.text-sm.font-medium');
    expect(labels.some(label => label.text() === 'Status')).toBe(true);
    wrapper.unmount();
  });

  it('keeps Portuguese accents intact and translation keys available in English', () => {
    expect(pt.CRM.NEW_DEAL).toBe('Novo negócio');
    expect(pt.CRM.NAME).toBe('Nome do negócio');
    expect(pt.CRM.DESCRIPTION).toBe('Descrição');
    expect(pt.CRM.SAVE_CHANGES).toBe('Salvar alterações');
    expect(
      Object.values(pt)
        .flatMap(section => Object.values(section))
        .some(value => value.includes('?') || value.includes('�'))
    ).toBe(false);
    expect(Object.keys(pt.CRM).every(key => key in en.CRM)).toBe(true);
  });
});
