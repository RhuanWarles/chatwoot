import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import CrmActivities from './CrmActivities.vue';
import CrmDealConversations from './CrmDealConversations.vue';
import { dealsAPI } from 'dashboard/api/crm';
import AgentsAPI from 'dashboard/api/agents';
import ContactAPI from 'dashboard/api/contacts';
import InboxesAPI from 'dashboard/api/inboxes';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';
vi.mock('dashboard/api/crm', () => ({ dealsAPI: { activities: vi.fn() } }));
vi.mock('dashboard/api/agents', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/api/contacts', () => ({
  default: { getConversations: vi.fn() },
}));
vi.mock('dashboard/api/inboxes', () => ({ default: { get: vi.fn() } }));
const api = { get: vi.fn(), create: vi.fn(), update: vi.fn() };
const DialogStub = {
  name: 'Dialog',
  data: () => ({ visible: false }),
  methods: {
    open() {
      this.visible = true;
    },
    close() {
      this.visible = false;
    },
  },
  template: '<div v-if="visible"><slot /></div>',
};
const LinkStub = { props: ['to'], template: '<a><slot /></a>' };
const ACTIVITY = {
  id: 3,
  activity_type: 'call',
  title: 'Follow-up',
  due_at: '2020-01-01T15:00:00Z',
  owner_id: 5,
  owner: { id: 5, name: 'Rhuan' },
  status: 'pending',
};
const setup = (component, props) =>
  mount(component, {
    props,
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'pt_BR', messages: { pt_BR: pt } }),
      ],
      stubs: { Dialog: DialogStub, RouterLink: LinkStub },
      mocks: { $route: { params: { accountId: '1' } } },
    },
  });
const button = (wrapper, key) =>
  wrapper.findAll('button').find(item => item.text() === pt.CRM[key]);
beforeEach(() => {
  vi.clearAllMocks();
  dealsAPI.activities.mockReturnValue(api);
  api.get.mockResolvedValue({ data: [ACTIVITY] });
  api.create.mockResolvedValue({ data: ACTIVITY });
  api.update.mockResolvedValue({ data: ACTIVITY });
  AgentsAPI.get.mockResolvedValue({ data: [{ id: 5, name: 'Rhuan' }] });
  ContactAPI.getConversations.mockResolvedValue({
    data: {
      payload: [
        { id: 42, inbox_id: 2, status: 'open', last_activity_at: 1700000000 },
      ],
    },
  });
  InboxesAPI.get.mockResolvedValue({
    data: { payload: [{ id: 2, name: 'WhatsApp' }] },
  });
});
it('shows overdue pending activities and owner', async () => {
  const wrapper = setup(CrmActivities, { deal: { id: 12 } });
  await flushPromises();
  expect(wrapper.text()).toContain(pt.CRM.ACTIVITY_OVERDUE);
  expect(wrapper.text()).toContain('Rhuan');
});
it('creates an activity with local date and time converted to ISO', async () => {
  const wrapper = setup(CrmActivities, { deal: { id: 12 } });
  await flushPromises();
  await button(wrapper, 'NEW_ACTIVITY').trigger('click');
  await flushPromises();
  await wrapper.find('input[type="text"]').setValue('New task');
  await wrapper.find('input[type="date"]').setValue('2026-10-03');
  await wrapper.find('input[type="time"]').setValue('10:30');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(api.create).toHaveBeenCalledWith({
    activity: expect.objectContaining({
      title: 'New task',
      activity_type: 'task',
      due_at: '2026-10-03T10:30:00.000Z',
      owner_id: null,
    }),
  });
  expect(wrapper.emitted('changed')).toHaveLength(1);
});
it('edits an activity without changing status', async () => {
  const wrapper = setup(CrmActivities, { deal: { id: 12 } });
  await flushPromises();
  await button(wrapper, 'EDIT_ACTIVITY').trigger('click');
  await flushPromises();
  await wrapper
    .findAll('input')
    .find(item => item.element.value === ACTIVITY.title)
    .setValue('Changed');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(api.update).toHaveBeenCalledWith(3, {
    activity: expect.objectContaining({ title: 'Changed', owner_id: 5 }),
  });
  expect(api.update.mock.calls[0][1].activity).not.toHaveProperty('status');
});
it.each([
  ['ACTIVITY_COMPLETE', 'completed'],
  ['ACTIVITY_CANCEL', 'cancelled'],
])('changes status using %s', async (key, status) => {
  const wrapper = setup(CrmActivities, { deal: { id: 12 } });
  await flushPromises();
  await button(wrapper, key).trigger('click');
  await flushPromises();
  expect(api.update).toHaveBeenCalledWith(3, { activity: { status } });
  expect(wrapper.emitted('changed')).toHaveLength(1);
});
it('preserves activities on failed update', async () => {
  api.update.mockRejectedValueOnce(new Error('failed'));
  const wrapper = setup(CrmActivities, { deal: { id: 12 } });
  await flushPromises();
  await button(wrapper, 'ACTIVITY_COMPLETE').trigger('click');
  await flushPromises();
  expect(wrapper.find('[role="alert"]').exists()).toBe(true);
  expect(wrapper.text()).toContain('Follow-up');
  expect(wrapper.emitted('changed')).toBeUndefined();
});
it('opens a permitted contact conversation using native route', async () => {
  const wrapper = setup(CrmDealConversations, { contactId: 3 });
  await flushPromises();
  expect(ContactAPI.getConversations).toHaveBeenCalledWith(3);
  expect(wrapper.text()).toContain('WhatsApp');
  expect(wrapper.findComponent(LinkStub).props('to')).toEqual({
    name: 'inbox_conversation',
    params: { accountId: '1', conversation_id: 42 },
  });
});
it('does not fetch conversations without a contact', async () => {
  const wrapper = setup(CrmDealConversations, { contactId: null });
  await flushPromises();
  expect(ContactAPI.getConversations).not.toHaveBeenCalled();
  expect(wrapper.text()).toContain(pt.CRM.NO_CONTACT_CONVERSATIONS);
});
