import { mount, flushPromises, config } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createStore } from 'vuex';
import CrmDealDetails from '../pages/CrmDealDetails.vue';
import CrmDeals from '../pages/CrmDeals.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import AgentsAPI from 'dashboard/api/agents';
import { dealsAPI, lostReasonsAPI, pipelinesAPI } from 'dashboard/api/crm';
import CrmLostReasonDialog from './CrmLostReasonDialog.vue';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';

config.global.plugins = [
  ...config.global.plugins,
  createStore({
    getters: {
      getCurrentRole: () => 'administrator',
      'agents/getAgents': () => [],
      'labels/getLabels': () => [],
      getUISettings: () => ({}),
    },
  }),
];

const { route, push } = vi.hoisted(() => ({
  route: { params: { accountId: '1', dealId: '12' }, query: {} },
  push: vi.fn(),
}));
vi.mock('vue-router', () => ({
  useRoute: () => route,
  useRouter: () => ({ push, replace: vi.fn() }),
}));
vi.mock('../components/CrmActivities.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('../components/CrmDealConversations.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('dashboard/api/agents', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/api/crm', () => ({
  segmentsAPI: { get: vi.fn() },
  lostReasonsAPI: { get: vi.fn() },
  dealsAPI: {
    customFields: vi.fn(),
    updateCustomFields: vi.fn(),
    show: vi.fn(),
    get: vi.fn(),
    update: vi.fn(),
    events: vi.fn(),
    addNote: vi.fn(),
    updateNote: vi.fn(),
    deleteNote: vi.fn(),
  },
  pipelinesAPI: { get: vi.fn() },
}));
const DEAL = {
  id: 12,
  name: 'Commercial deal',
  pipeline_id: 1,
  pipeline_stage_id: 10,
  contact_id: 3,
  owner_id: null,
  status: 'open',
  value: '2500.00',
  description: 'Details',
  created_at: '2026-10-02T12:00:00Z',
  updated_at: '2026-10-02T13:00:00Z',
  pipeline: { id: 1, name: 'Sales' },
  pipeline_stage: { id: 10, name: 'Lead' },
  contact: {
    id: 3,
    name: 'Customer',
    phone_number: '+5562999999999',
    email: 'customer@example.com',
    additional_attributes: { company_name: 'Company' },
  },
};
const PIPELINE = {
  id: 1,
  name: 'Sales',
  active: true,
  stages: [
    { id: 10, name: 'Lead' },
    { id: 20, name: 'Proposal' },
  ],
};
const DialogStub = {
  name: 'Dialog',
  props: ['title', 'disableConfirmButton'],
  emits: ['confirm'],
  data: () => ({ visible: false }),
  methods: {
    open() {
      this.visible = true;
    },
    close() {
      this.visible = false;
    },
  },
  template: `<div v-if="visible" class="dialog"><slot /><button class="confirm" :disabled="disableConfirmButton" @click="$emit('confirm')">{{ title }}</button></div>`,
};
const RouterLinkStub = { props: ['to'], template: '<a><slot /></a>' };
const mountPage = async () => {
  const wrapper = mount(CrmDealDetails, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'pt_BR', messages: { pt_BR: pt } }),
      ],
      stubs: {
        Dialog: DialogStub,
        RouterLink: RouterLinkStub,
        CrmContactPicker: true,
      },
    },
  });
  await flushPromises();
  return wrapper;
};
const click = async (wrapper, label) => {
  await wrapper
    .findAll('button')
    .find(button => button.text() === label)
    .trigger('click');
  await flushPromises();
};
const LOST_REASONS = [
  { id: 1, name: 'Sem orçamento', active: true },
  { id: 2, name: 'Fechou com concorrente', active: true },
];
beforeEach(() => {
  vi.clearAllMocks();
  lostReasonsAPI.get.mockResolvedValue({ data: [] });
  dealsAPI.customFields.mockResolvedValue({ data: [] });
  dealsAPI.show.mockResolvedValue({ data: structuredClone(DEAL) });
  dealsAPI.get.mockResolvedValue({ data: [structuredClone(DEAL)] });
  dealsAPI.events.mockResolvedValue({
    data: {
      payload: [
        {
          id: 1,
          event_type: 'deal_created',
          metadata: {},
          actor: { name: 'Agent' },
          created_at: DEAL.created_at,
        },
      ],
      meta: { has_more: false },
    },
  });
  dealsAPI.update.mockImplementation(async (_, payload) => ({
    data: { ...structuredClone(DEAL), ...payload.deal },
  }));
  dealsAPI.addNote.mockResolvedValue({ data: {} });
  pipelinesAPI.get.mockResolvedValue({ data: [PIPELINE] });
  AgentsAPI.get.mockResolvedValue({ data: [{ id: 7, name: 'Owner' }] });
});
describe('Deal details', () => {
  it('loads directly by URL and shows native contact data', async () => {
    const wrapper = await mountPage();
    expect(dealsAPI.show).toHaveBeenCalledWith(
      '12',
      expect.objectContaining({ signal: expect.any(AbortSignal) })
    );
    expect(wrapper.text()).toContain('Commercial deal');
    expect(wrapper.text()).toContain('customer@example.com');
    expect(wrapper.text()).toContain('Company');
    expect(
      wrapper
        .findAllComponents(RouterLinkStub)
        .some(link => link.props('to').name === 'contacts_edit')
    ).toBe(true);
  });
  it('loads again on browser refresh/remount', async () => {
    const wrapper = await mountPage();
    wrapper.unmount();
    await mountPage();
    expect(dealsAPI.show).toHaveBeenCalledTimes(2);
  });
  it.each([404, 403])('handles unavailable deal with HTTP %i', async status => {
    dealsAPI.show.mockRejectedValueOnce({ response: { status } });
    const wrapper = await mountPage();
    expect(wrapper.find('[role=alert]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('Commercial deal');
  });
  it('marks won without moving stages', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.STATUS_WON);
    expect(dealsAPI.update).toHaveBeenCalledWith(12, {
      deal: { status: 'won' },
    });
    expect(dealsAPI.events).toHaveBeenCalledTimes(2);
  });
  it('marks lost without moving stages when no lost reason is configured', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.STATUS_LOST);
    expect(dealsAPI.update).toHaveBeenCalledWith(12, {
      deal: { status: 'lost' },
    });
  });
  it('edits stage, numeric value and owner in place', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.EDIT_DEAL);
    const pickers = wrapper.findAllComponents(ComboBox);
    pickers[1].vm.$emit('update:modelValue', 20);
    pickers[2].vm.$emit('update:modelValue', 7);
    const currency = wrapper
      .find('.dialog')
      .findAll('input')
      .find(input => input.attributes('inputmode') === 'decimal');
    await currency.trigger('focus');
    await currency.setValue('3.000,00');
    await wrapper.find('.confirm').trigger('click');
    await flushPromises();
    expect(dealsAPI.update).toHaveBeenCalledWith(12, {
      deal: expect.objectContaining({
        pipeline_stage_id: 20,
        owner_id: 7,
        value: 3000,
        status: 'open',
      }),
    });
  });
  it('adds a note and refreshes history', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.ADD_NOTE);
    await wrapper.find('textarea').setValue('New note');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(dealsAPI.addNote).toHaveBeenCalledWith(12, 'New note');
    expect(wrapper.find('textarea').exists()).toBe(false);
    expect(dealsAPI.events).toHaveBeenCalledTimes(2);
  });
  it('keeps note content when save fails', async () => {
    dealsAPI.addNote.mockRejectedValueOnce(new Error('failure'));
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.ADD_NOTE);
    await wrapper.find('textarea').setValue('Keep note');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(wrapper.find('textarea').element.value).toBe('Keep note');
    expect(wrapper.find('[role=alert]').text()).toBe(pt.CRM.NOTE_SAVE_ERROR);
  });
  it('filters notes and renders user text safely', async () => {
    dealsAPI.events.mockResolvedValue({
      data: {
        payload: [
          {
            id: 2,
            event_type: 'note_created',
            metadata: { body: '<script>alert(1)</script>' },
            created_at: DEAL.created_at,
          },
          {
            id: 1,
            event_type: 'deal_created',
            metadata: {},
            created_at: DEAL.created_at,
          },
        ],
        meta: { has_more: false },
      },
    });
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.NOTES);
    expect(wrapper.findAll('li')).toHaveLength(1);
    expect(wrapper.find('script').exists()).toBe(false);
    expect(wrapper.text()).toContain('<script>alert(1)</script>');
  });
  it('links back to the deal pipeline in the account Kanban', async () => {
    const wrapper = await mountPage();
    expect(wrapper.findComponent(RouterLinkStub).props('to')).toEqual({
      name: 'crm_deals',
      params: { accountId: '1' },
      query: { pipeline_id: DEAL.pipeline_id },
    });
  });
  it('opens the detail route on card click and keeps a separate quick edit', async () => {
    const wrapper = mount(CrmDeals, {
      global: {
        plugins: [
          createI18n({
            legacy: false,
            locale: 'pt_BR',
            messages: { pt_BR: pt },
          }),
        ],
        stubs: {
          Popover: { template: '<span><slot /></span>' },
          RouterLink: RouterLinkStub,
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
    await wrapper.find('article').trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'crm_deal_details',
      params: { accountId: '1', dealId: 12 },
    });
    await wrapper.find('article button[aria-label]').trigger('click');
    expect(wrapper.findAllComponents(Input).length).toBeGreaterThan(0);
    expect(push).toHaveBeenCalledTimes(1);
  });
});

it('edits an authorized note while retaining the original event', async () => {
  const event = {
    id: 7,
    event_type: 'note_created',
    metadata: { body: 'Original' },
    actor: { name: 'Agent' },
    created_at: DEAL.created_at,
    can_edit: true,
    can_delete: true,
  };
  dealsAPI.events.mockResolvedValue({
    data: { payload: [event], meta: { has_more: false } },
  });
  dealsAPI.updateNote.mockResolvedValue({ data: {} });
  const wrapper = await mountPage();
  await click(wrapper, pt.CRM.EDIT_NOTE);
  expect(wrapper.find('textarea').element.value).toBe('Original');
  await wrapper.find('textarea').setValue('Edited');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(dealsAPI.updateNote).toHaveBeenCalledWith(12, 7, 'Edited');
  expect(dealsAPI.addNote).not.toHaveBeenCalled();
});
it('requires confirmation before deleting an authorized note', async () => {
  const event = {
    id: 7,
    event_type: 'note_created',
    metadata: { body: 'Original' },
    actor: { name: 'Agent' },
    created_at: DEAL.created_at,
    can_edit: true,
    can_delete: true,
  };
  dealsAPI.events.mockResolvedValue({
    data: { payload: [event], meta: { has_more: false } },
  });
  dealsAPI.deleteNote.mockResolvedValue({ data: {} });
  const wrapper = await mountPage();
  await click(wrapper, pt.CRM.DELETE_NOTE);
  expect(dealsAPI.deleteNote).not.toHaveBeenCalled();
  await wrapper.find('.dialog .confirm').trigger('click');
  await flushPromises();
  expect(dealsAPI.deleteNote).toHaveBeenCalledWith(12, 7);
});
it('hides note mutations when backend denies permissions', async () => {
  dealsAPI.events.mockResolvedValue({
    data: {
      payload: [
        {
          id: 7,
          event_type: 'note_created',
          metadata: { body: 'Other author' },
          created_at: DEAL.created_at,
          can_edit: false,
          can_delete: false,
        },
      ],
      meta: { has_more: false },
    },
  });
  const wrapper = await mountPage();
  expect(
    wrapper
      .findAll('button')
      .some(button =>
        [pt.CRM.EDIT_NOTE, pt.CRM.DELETE_NOTE].includes(button.text())
      )
  ).toBe(false);
});

it('shows cancellation reason and actor in the Deal timeline', async () => {
  dealsAPI.events.mockResolvedValue({
    data: {
      payload: [
        {
          id: 9,
          event_type: 'activity_cancelled',
          metadata: {
            title: 'Client follow-up',
            due_at: '2026-10-04T12:00:00Z',
            cancellation_reason: 'Client requested next month.',
            cancelled_at: '2026-10-03T02:20:00Z',
            cancelled_by_name: 'Rhuan',
          },
          actor: { name: 'Rhuan' },
          created_at: '2026-10-03T02:20:00Z',
        },
      ],
      meta: { has_more: false },
    },
  });
  const wrapper = await mountPage();
  expect(wrapper.text()).toContain(pt.CRM.EVENT_ACTIVITY_CANCELLED);
  expect(wrapper.text()).toContain('Client follow-up');
  expect(wrapper.text()).toContain('Client requested next month.');
  expect(wrapper.text()).toContain('Cancelado por Rhuan');
  expect(wrapper.text()).toContain('03/10/2026');
  wrapper.unmount();
});

it('keeps Details in the sidebar and independently collapses Summary', async () => {
  const wrapper = await mountPage();
  expect(wrapper.find('aside [aria-controls="deal-details-12"]').exists()).toBe(
    true
  );
  const toggle = wrapper.find('[aria-controls="deal-summary"]');
  expect(toggle.attributes('aria-expanded')).toBe('true');
  await toggle.trigger('click');
  expect(toggle.attributes('aria-expanded')).toBe('false');
  expect(wrapper.find('#deal-summary').isVisible()).toBe(false);
  expect(
    wrapper
      .find('[aria-controls="deal-details-12"]')
      .attributes('aria-expanded')
  ).toBe('true');
  await toggle.trigger('click');
  expect(toggle.attributes('aria-expanded')).toBe('true');
  expect(wrapper.find('#deal-summary').attributes('style') || '').not.toContain(
    'display: none'
  );
  expect(wrapper.find('main').classes()).toContain('lg:overflow-hidden');
  expect(wrapper.find('aside').classes()).toContain('lg:overflow-y-auto');
});

describe('Lost reason', () => {
  const chooseReason = async (wrapper, index, note) => {
    await wrapper.findAll('input[type="radio"]')[index].setValue();
    if (note) await wrapper.find('textarea').setValue(note);
    await wrapper.findAll('.confirm').at(-1).trigger('click');
    await flushPromises();
  };

  beforeEach(() => {
    lostReasonsAPI.get.mockResolvedValue({ data: LOST_REASONS });
  });

  it('asks for the reason and sends it with the Lost button', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.STATUS_LOST);

    expect(dealsAPI.update).not.toHaveBeenCalled();
    expect(
      wrapper.findAll('[data-test="lost-reason"]').map(reason => reason.text())
    ).toEqual(['Sem orçamento', 'Fechou com concorrente']);

    await chooseReason(wrapper, 1, 'Preço menor');

    expect(dealsAPI.update).toHaveBeenCalledWith(12, {
      deal: { status: 'lost', lost_reason_id: 2, lost_note: 'Preço menor' },
    });
  });

  it('keeps the deal as it was when the popup is cancelled', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.STATUS_LOST);

    wrapper.findComponent(CrmLostReasonDialog).vm.$emit('cancel');
    await flushPromises();

    expect(dealsAPI.update).not.toHaveBeenCalled();
    expect(wrapper.findComponent(CrmLostReasonDialog).exists()).toBe(false);
  });

  it('does not ask for a reason to mark the deal as won', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.STATUS_WON);

    expect(dealsAPI.update).toHaveBeenCalledWith(12, {
      deal: { status: 'won' },
    });
  });

  it('asks for the reason when the edit dialog sets the status to lost', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.EDIT_DEAL);
    wrapper
      .findAllComponents(ComboBox)
      .find(picker =>
        picker.props('options').some(item => item.value === 'lost')
      )
      .vm.$emit('update:modelValue', 'lost');
    await wrapper.find('.confirm').trigger('click');
    await flushPromises();

    expect(dealsAPI.update).not.toHaveBeenCalled();
    await chooseReason(wrapper, 0);

    expect(dealsAPI.update).toHaveBeenCalledWith(12, {
      deal: expect.objectContaining({
        status: 'lost',
        lost_reason_id: 1,
        lost_note: null,
      }),
    });
  });

  it('asks for the reason when the summary status is edited to lost', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.FILTER_OPEN);
    wrapper
      .find('#deal-summary')
      .findAllComponents(ComboBox)
      .find(picker =>
        picker.props('options').some(item => item.value === 'lost')
      )
      .vm.$emit('update:modelValue', 'lost');
    await wrapper.find('#deal-summary form').trigger('submit');
    await flushPromises();

    expect(dealsAPI.update).not.toHaveBeenCalled();
    await chooseReason(wrapper, 1);

    expect(dealsAPI.update).toHaveBeenCalledWith(12, {
      deal: { status: 'lost', lost_reason_id: 2, lost_note: null },
    });
  });

  it('shows the reason and the note of a lost deal', async () => {
    dealsAPI.show.mockResolvedValue({
      data: {
        ...structuredClone(DEAL),
        status: 'lost',
        lost_reason_id: 1,
        lost_reason: { id: 1, name: 'Sem orçamento' },
        lost_note: 'Cliente sem verba até 2027',
      },
    });
    const wrapper = await mountPage();

    expect(wrapper.find('header').text()).toContain('Motivo: Sem orçamento');
    expect(wrapper.find('header').text()).toContain(
      'Observação: Cliente sem verba até 2027'
    );
  });

  it('shows the reason in the status change of the timeline', async () => {
    dealsAPI.events.mockResolvedValue({
      data: {
        payload: [
          {
            id: 5,
            event_type: 'status_changed',
            metadata: {
              from: 'open',
              to: 'lost',
              lost_reason: 'Sem orçamento',
              lost_note: 'Cliente sem verba',
            },
            created_at: DEAL.created_at,
          },
        ],
        meta: { has_more: false },
      },
    });
    const wrapper = await mountPage();

    expect(wrapper.text()).toContain('Em andamento → Perdido');
    expect(wrapper.text()).toContain('Motivo: Sem orçamento');
    expect(wrapper.text()).toContain('Observação: Cliente sem verba');
  });
});
