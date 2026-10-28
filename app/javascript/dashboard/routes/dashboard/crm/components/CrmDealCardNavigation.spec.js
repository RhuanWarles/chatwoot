import { config, flushPromises, mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';

import ContactAPI from 'dashboard/api/contacts';
import { useAlert } from 'dashboard/composables';
import { dealsAPI, pipelinesAPI, segmentsAPI } from 'dashboard/api/crm';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';
import CrmDeals from '../pages/CrmDeals.vue';

const router = vi.hoisted(() => ({ push: vi.fn(), replace: vi.fn() }));
vi.mock('dashboard/api/crm', () => ({
  pipelinesAPI: { get: vi.fn() },
  dealsAPI: { get: vi.fn(), create: vi.fn(), update: vi.fn() },
  segmentsAPI: { get: vi.fn() },
}));
vi.mock('dashboard/api/contacts', () => ({
  default: { getConversations: vi.fn() },
}));
vi.mock('dashboard/composables', async importOriginal => ({
  ...(await importOriginal()),
  useAlert: vi.fn(),
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' }, query: {} }),
  useRouter: () => router,
}));

config.global.plugins = [
  createStore({
    getters: {
      getCurrentRole: () => 'administrator',
      'agents/getAgents': () => [],
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

const DEAL = {
  id: 9,
  name: 'Venda do Jorge',
  status: 'open',
  value: '1000.00',
  contact_id: 30,
  pipeline_id: 1,
  pipeline_stage_id: 10,
  segment_id: null,
  answered_by: { user_ids: [], ai: false },
};

const mountBoard = async () => {
  const wrapper = mount(CrmDeals);
  await flushPromises();
  return wrapper;
};
const clickCard = async wrapper => {
  await wrapper.find('article').trigger('click');
  await flushPromises();
};

beforeEach(() => {
  vi.clearAllMocks();
  pipelinesAPI.get.mockResolvedValue({
    data: [
      {
        id: 1,
        name: 'Comercial',
        active: true,
        stages: [{ id: 10, name: 'Lead' }],
      },
    ],
  });
  dealsAPI.get.mockResolvedValue({ data: [{ ...DEAL }] });
  segmentsAPI.get.mockResolvedValue({ data: [] });
});

describe('Kanban card click', () => {
  it('opens the latest conversation of the customer', async () => {
    ContactAPI.getConversations.mockResolvedValue({
      data: { payload: [{ id: 77 }, { id: 60 }] },
    });
    const wrapper = await mountBoard();

    await clickCard(wrapper);

    expect(ContactAPI.getConversations).toHaveBeenCalledWith(30);
    expect(router.push).toHaveBeenCalledTimes(1);
    expect(router.push).toHaveBeenCalledWith({
      name: 'inbox_conversation',
      params: { accountId: '1', conversation_id: 77 },
    });
    wrapper.unmount();
  });

  it('opens the deal page when the customer has no conversation yet', async () => {
    ContactAPI.getConversations.mockResolvedValue({ data: { payload: [] } });
    const wrapper = await mountBoard();

    await clickCard(wrapper);

    expect(useAlert).toHaveBeenCalledWith(pt.CRM.NO_CONVERSATION);
    expect(router.push).toHaveBeenCalledWith({
      name: 'crm_deal_details',
      params: { accountId: '1', dealId: 9 },
    });
    wrapper.unmount();
  });

  it('opens the deal page when the conversations cannot be loaded', async () => {
    ContactAPI.getConversations.mockRejectedValue(new Error('500'));
    const wrapper = await mountBoard();

    await clickCard(wrapper);

    expect(router.push).toHaveBeenCalledWith({
      name: 'crm_deal_details',
      params: { accountId: '1', dealId: 9 },
    });
    wrapper.unmount();
  });

  it('has a button that always goes to the deal page without looking for conversations', async () => {
    const wrapper = await mountBoard();

    await wrapper
      .find(`article button[aria-label="${pt.CRM.LEAD_OPEN_DEAL}"]`)
      .trigger('click');
    await flushPromises();

    expect(ContactAPI.getConversations).not.toHaveBeenCalled();
    expect(router.push).toHaveBeenCalledWith({
      name: 'crm_deal_details',
      params: { accountId: '1', dealId: 9 },
    });
    wrapper.unmount();
  });

  it('ignores a second click while the conversation is being looked up', async () => {
    let finish;
    ContactAPI.getConversations.mockReturnValue(
      new Promise(resolve => {
        finish = resolve;
      })
    );
    const wrapper = await mountBoard();

    await wrapper.find('article').trigger('click');
    await wrapper.find('article').trigger('click');
    finish({ data: { payload: [{ id: 77 }] } });
    await flushPromises();

    expect(ContactAPI.getConversations).toHaveBeenCalledTimes(1);
    expect(router.push).toHaveBeenCalledTimes(1);
    wrapper.unmount();
  });
});
