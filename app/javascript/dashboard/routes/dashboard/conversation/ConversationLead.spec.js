import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createStore } from 'vuex';
import ConversationLead from './ConversationLead.vue';
import { dealsAPI, pipelinesAPI } from 'dashboard/api/crm';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';

const router = vi.hoisted(() => ({ push: vi.fn() }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => router,
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/crm', () => ({
  dealsAPI: { get: vi.fn(), create: vi.fn(), update: vi.fn() },
  pipelinesAPI: { get: vi.fn() },
}));

const CONTACT = { id: 30, name: 'Jorge' };
const PIPELINES = [
  {
    id: 1,
    name: 'Sales',
    active: true,
    stages: [
      { id: 10, name: 'Lead' },
      { id: 11, name: 'Proposal' },
    ],
  },
];
const DEAL = {
  id: 5,
  name: 'Jorge deal',
  status: 'open',
  value: '1500.00',
  pipeline_id: 1,
  pipeline_stage_id: 10,
  pipeline_stage: { id: 10, name: 'Lead' },
};

const mountLead = () =>
  mount(ConversationLead, {
    props: { contact: CONTACT },
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: { ...pt, CRM: pt.CRM } },
        }),
        createStore({}),
      ],
      stubs: {
        CrmDealCustomFields: { template: '<div data-custom-fields />' },
      },
    },
  });

beforeEach(() => {
  vi.clearAllMocks();
  pipelinesAPI.get.mockResolvedValue({ data: PIPELINES });
  dealsAPI.get.mockResolvedValue({ data: [DEAL] });
  dealsAPI.update.mockResolvedValue({ data: DEAL });
  dealsAPI.create.mockResolvedValue({ data: { id: 6 } });
});

describe('ConversationLead', () => {
  it('loads the contact deals and shows the custom fields of the open deal', async () => {
    const wrapper = mountLead();
    await flushPromises();
    expect(dealsAPI.get).toHaveBeenCalledWith({
      params: { contact_id: CONTACT.id },
    });
    expect(wrapper.find('[data-custom-fields]').exists()).toBe(true);
    expect(wrapper.text()).toContain(pt.CRM.STAGE);
  });

  it('moves the card when another stage is selected', async () => {
    const wrapper = mountLead();
    await flushPromises();
    wrapper
      .findAllComponents({ name: 'ComboBox' })[0]
      .vm.$emit('update:modelValue', 11);
    await flushPromises();
    expect(dealsAPI.update).toHaveBeenCalledWith(5, {
      deal: { pipeline_stage_id: 11 },
    });
  });

  describe('with more than one pipeline', () => {
    const SECOND = {
      id: 2,
      name: 'Post-sale',
      active: true,
      stages: [
        { id: 22, name: 'Onboarding', position: 1 },
        { id: 21, name: 'Welcome', position: 0 },
      ],
    };
    const INACTIVE = {
      id: 3,
      name: 'Old',
      active: false,
      stages: [{ id: 31, name: 'X' }],
    };

    beforeEach(() => {
      pipelinesAPI.get.mockResolvedValue({
        data: [...PIPELINES, SECOND, INACTIVE],
      });
    });

    it('offers the active pipelines to change the deal to', async () => {
      const wrapper = mountLead();
      await flushPromises();
      const [pipelineSelect] = wrapper.findAllComponents({ name: 'ComboBox' });
      expect(pipelineSelect.props('modelValue')).toBe(1);
      expect(
        pipelineSelect.props('options').map(option => option.label)
      ).toEqual(['Sales', 'Post-sale']);
    });

    it('moves the deal to the first stage of the chosen pipeline', async () => {
      const wrapper = mountLead();
      await flushPromises();
      wrapper
        .findAllComponents({ name: 'ComboBox' })[0]
        .vm.$emit('update:modelValue', 2);
      await flushPromises();
      expect(dealsAPI.update).toHaveBeenCalledWith(5, {
        deal: { pipeline_id: 2, pipeline_stage_id: 21 },
      });
    });

    it('does not call the API when the pipeline has no stages', async () => {
      pipelinesAPI.get.mockResolvedValue({
        data: [...PIPELINES, { ...SECOND, stages: [] }],
      });
      const wrapper = mountLead();
      await flushPromises();
      wrapper
        .findAllComponents({ name: 'ComboBox' })[0]
        .vm.$emit('update:modelValue', 2);
      await flushPromises();
      expect(dealsAPI.update).not.toHaveBeenCalled();
    });
  });

  it('creates a deal in the first stage of the first active pipeline when none exists', async () => {
    dealsAPI.get.mockResolvedValue({ data: [] });
    const wrapper = mountLead();
    await flushPromises();
    expect(wrapper.text()).toContain(pt.CRM.LEAD_NO_DEAL);
    await wrapper
      .findAll('button')
      .find(button => button.text() === pt.CRM.NEW_DEAL)
      .trigger('click');
    await flushPromises();
    expect(dealsAPI.create).toHaveBeenCalledWith({
      deal: {
        name: 'Jorge',
        contact_id: 30,
        pipeline_id: 1,
        pipeline_stage_id: 10,
      },
    });
  });
});
