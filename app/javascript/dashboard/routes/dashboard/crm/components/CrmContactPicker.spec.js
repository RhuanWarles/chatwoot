import { config, mount, flushPromises } from '@vue/test-utils';
import CrmContactPicker from './CrmContactPicker.vue';
import contactsAPI from 'dashboard/api/contacts';
import { formatContactPhone } from './contactHelpers';

config.global.stubs.CrmInlineContactDialog = true;

vi.mock('dashboard/api/contacts', () => ({
  default: { get: vi.fn(), search: vi.fn() },
}));

const CONTACTS = [
  {
    id: 1,
    name: 'Same Name',
    phone_number: '+5562999999999',
    email: 'first@example.com',
    thumbnail: '/first.png',
  },
  {
    id: 2,
    name: 'Same Name',
    phone_number: '+5511988887777',
    email: 'second@example.com',
    thumbnail: '/second.png',
  },
  { id: 3, name: 'Email Only', phone_number: null, email: 'email@example.com' },
  { id: 4, name: 'Phone Only', phone_number: '+5511999999999', email: null },
  { id: 5, name: 'Name Only', phone_number: null, email: null },
];

describe('CrmContactPicker', () => {
  beforeEach(() => {
    contactsAPI.get.mockResolvedValue({ data: { payload: CONTACTS } });
    contactsAPI.search.mockResolvedValue({ data: { payload: CONTACTS } });
  });

  it('distinguishes identical names by phone, email and native avatar', async () => {
    const wrapper = mount(CrmContactPicker);
    await wrapper.find('button').trigger('click');
    await flushPromises();
    const rows = wrapper.findAll('[role="option"]');
    expect(rows[0].text()).toContain(
      formatContactPhone(CONTACTS[0].phone_number)
    );
    expect(rows[0].text()).toContain(CONTACTS[0].email);
    expect(rows[1].text()).toContain(
      formatContactPhone(CONTACTS[1].phone_number)
    );
    expect(rows[1].text()).toContain(CONTACTS[1].email);
    expect(rows[0].find('img').attributes('src')).toBe('/first.png');
    expect(rows[1].find('img').attributes('src')).toBe('/second.png');
    wrapper.unmount();
  });

  it('omits missing phone and email lines without placeholder values', async () => {
    const wrapper = mount(CrmContactPicker);
    await wrapper.find('button').trigger('click');
    await flushPromises();
    const rows = wrapper.findAll('[role="option"]');
    expect(rows[2].findAll('.text-xs')).toHaveLength(1);
    expect(rows[3].findAll('.text-xs')).toHaveLength(1);
    expect(rows[4].findAll('.text-xs')).toHaveLength(0);
    expect(rows[4].find('.text-start > .font-medium').text()).toBe('Name Only');
    expect(wrapper.text()).not.toMatch(/undefined|null/);
    wrapper.unmount();
  });

  it.each([
    [CONTACTS[0], formatContactPhone(CONTACTS[0].phone_number)],
    [CONTACTS[2], CONTACTS[2].email],
    [CONTACTS[4], null],
  ])(
    'shows the selected contact with phone or email when available',
    async (contact, secondary) => {
      const wrapper = mount(CrmContactPicker, {
        props: { modelValue: contact.id, contact },
      });
      const trigger = wrapper.find('button');
      expect(trigger.text()).toContain(contact.name);
      if (secondary) expect(trigger.text()).toContain(secondary);
      else expect(trigger.find('.text-xs').exists()).toBe(false);
      wrapper.unmount();
    }
  );

  it.each(['Same Name', '+5562999999999', 'first@example.com'])(
    'uses native contact search for %s',
    async query => {
      const wrapper = mount(CrmContactPicker);
      await wrapper.find('button').trigger('click');
      await flushPromises();
      await wrapper.find('input[type="search"]').setValue(query);
      await flushPromises();
      expect(contactsAPI.search).toHaveBeenLastCalledWith(
        query,
        1,
        'name',
        '',
        { signal: expect.any(AbortSignal) }
      );
      expect(wrapper.findAll('[role="option"]')).toHaveLength(CONTACTS.length);
      wrapper.unmount();
    }
  );

  it('selects the correct id for contacts with identical names', async () => {
    const wrapper = mount(CrmContactPicker);
    await wrapper.find('button').trigger('click');
    await flushPromises();
    await wrapper.findAll('[role="option"]')[1].trigger('click');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([2]);
    expect(wrapper.find('button').text()).toContain(
      formatContactPhone(CONTACTS[1].phone_number)
    );
    wrapper.unmount();
  });
});
