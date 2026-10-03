import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import CrmDeals from '../pages/CrmDeals.vue';
import { dealsAPI, pipelinesAPI } from 'dashboard/api/crm';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('dashboard/api/crm', () => ({
  dealsAPI: { get: vi.fn() },
  pipelinesAPI: { get: vi.fn() },
}));
const deal = {
  id: 12,
  name: 'Contract',
  pipeline_id: 1,
  pipeline_stage_id: 10,
  status: 'open',
  value: '2500',
  contact: {
    id: 3,
    name: 'Customer',
    phone_number: '+5562999999999',
    email: 'customer@example.com',
    company: { id: 4, name: 'Company' },
  },
};
const popover = {
  data: () => ({ visible: false }),
  emits: ['show', 'hide'],
  methods: {
    show() {
      this.visible = true;
      this.$emit('show');
    },
    hide() {
      this.visible = false;
      this.$emit('hide');
    },
  },
  template:
    '<span><slot /></span><div v-if="visible"><slot name="content" :hide="hide" /></div>',
};
let wrapper;
beforeEach(async () => {
  vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'] });
  vi.clearAllMocks();
  pipelinesAPI.get.mockResolvedValue({
    data: [
      {
        id: 1,
        name: 'Sales',
        active: true,
        stages: [{ id: 10, name: 'Lead' }],
      },
    ],
  });
  dealsAPI.get.mockResolvedValue({ data: [deal] });
  wrapper = mount(CrmDeals, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'pt_BR', messages: { pt_BR: pt } }),
      ],
      stubs: {
        Popover: popover,
        RouterLink: {
          name: 'RouterLink',
          props: ['to'],
          template: '<a><slot /></a>',
        },
        CrmContactPicker: true,
        Draggable: {
          props: ['modelValue'],
          template:
            '<div><slot v-for="item in modelValue" name="item" :element="item" /></div>',
        },
      },
    },
  });
  await flushPromises();
});
afterEach(() => {
  wrapper.unmount();
  vi.useRealTimers();
});
it('debounces typing and does not require Enter', async () => {
  const input = wrapper.find('input[type=search]');
  await input.setValue('C');
  await vi.advanceTimersByTimeAsync(200);
  await input.setValue('Contract');
  await vi.advanceTimersByTimeAsync(299);
  expect(dealsAPI.get).toHaveBeenCalledTimes(1);
  await vi.advanceTimersByTimeAsync(1);
  expect(dealsAPI.get).toHaveBeenCalledTimes(2);
  expect(dealsAPI.get.mock.lastCall[0].params).toEqual({
    pipeline_id: 1,
    q: 'Contract',
  });
  expect(wrapper.find('[role=region]').text()).toContain(
    'customer@example.com'
  );
});
it('clears immediately and ignores a response from an older search', async () => {
  let finish;
  dealsAPI.get.mockImplementationOnce(
    () =>
      new Promise(resolve => {
        finish = resolve;
      })
  );
  const input = wrapper.find('input[type=search]');
  await input.setValue('missing');
  await vi.advanceTimersByTimeAsync(300);
  await input.setValue('');
  expect(wrapper.find('article').text()).toContain('Contract');
  expect(wrapper.find('[role=region]').exists()).toBe(false);
  finish({ data: [] });
  await flushPromises();
  expect(wrapper.findAll('article')).toHaveLength(1);
  expect(dealsAPI.get.mock.lastCall[0].params.q).toBe('');
});
it('does not duplicate an Enter search or fire after leaving the page', async () => {
  await wrapper.find('input[type=search]').setValue('Contract');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  await vi.advanceTimersByTimeAsync(300);
  expect(dealsAPI.get).toHaveBeenCalledTimes(2);
  await wrapper.find('input[type=search]').setValue('Customer');
  wrapper.unmount();
  await vi.advanceTimersByTimeAsync(300);
  expect(dealsAPI.get).toHaveBeenCalledTimes(2);
});
it('renders limited suggestions and account-scoped native links', async () => {
  dealsAPI.get.mockResolvedValue({
    data: Array.from({ length: 12 }, (_, index) => ({
      ...deal,
      id: index + 12,
    })),
  });
  await wrapper.find('input[type=search]').setValue('Customer');
  await vi.advanceTimersByTimeAsync(300);
  const links = wrapper.findAllComponents({ name: 'RouterLink' });
  const region = wrapper.find('[role=region]');
  expect(region.findAll('a')).toHaveLength(10);
  expect(region.text()).toContain('2.500,00');
  expect(region.text()).toContain(pt.CRM.DEAL_SEARCH_VIEW_ALL);
  expect(wrapper.findAll('article')).toHaveLength(12);
  expect(links.map(link => link.props('to'))).toContainEqual({
    name: 'contacts_edit',
    params: { accountId: '1', contactId: 3 },
  });
  expect(links.map(link => link.props('to'))).toContainEqual({
    name: 'companies_dashboard_show',
    params: { accountId: '1', companyId: 4 },
  });
});
