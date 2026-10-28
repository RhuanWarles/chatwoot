import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';

import messages from 'dashboard/i18n/locale/pt_BR/contact.json';
import CsNotesAPI from 'dashboard/api/csNotes';
import { resetCsNotes } from 'dashboard/composables/useCsNotes';
import CsNotesPanel from '../CsNotesPanel.vue';

const mocks = vi.hoisted(() => ({ alert: vi.fn() }));
vi.mock('dashboard/composables', () => ({ useAlert: mocks.alert }));
vi.mock('dashboard/api/csNotes', () => ({
  default: {
    getSettings: vi.fn(),
    getValues: vi.fn(),
    saveValues: vi.fn(),
  },
}));

const plan = {
  id: 1,
  attribute_key: 'plano',
  attribute_display_name: 'Plano',
  attribute_display_type: 'text',
};
const risk = {
  id: 2,
  attribute_key: 'risco',
  attribute_display_name: 'Risco',
  attribute_display_type: 'list',
  attribute_values: ['Baixo', 'Alto'],
};

const FieldInputStub = {
  props: ['field', 'modelValue'],
  emits: ['commit'],
  template:
    '<input :data-test="\'stub-\' + field.attribute_key" :value="modelValue" @change="$emit(\'commit\', $event.target.value)" />',
};

const mountPanel = async (props = {}) => {
  const wrapper = mount(CsNotesPanel, {
    props: { contactId: 10, ...props },
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: { CsFieldInput: FieldInputStub, CsFieldsManager: true },
    },
  });
  await flushPromises();
  return wrapper;
};

const allow = (fields = [plan, risk]) =>
  CsNotesAPI.getSettings.mockResolvedValue({
    data: { can_access: true, can_manage: false, fields },
  });

beforeEach(() => {
  vi.clearAllMocks();
  resetCsNotes();
  CsNotesAPI.getValues.mockResolvedValue({
    data: { field_values: { plano: 'Pro' } },
  });
});

describe('CsNotesPanel', () => {
  it('shows nothing to someone who has no access, and never asks for the values', async () => {
    CsNotesAPI.getSettings.mockResolvedValue({
      data: { can_access: false, can_manage: false },
    });

    const wrapper = await mountPanel();

    expect(wrapper.find('[data-test="cs-note-field"]').exists()).toBe(false);
    expect(wrapper.find('[data-test="cs-manage"]').exists()).toBe(false);
    expect(CsNotesAPI.getValues).not.toHaveBeenCalled();
  });

  it('lists the fields with the values of the contact', async () => {
    allow();

    const wrapper = await mountPanel();

    expect(CsNotesAPI.getValues).toHaveBeenCalledWith(10);
    const rows = wrapper.findAll('[data-test="cs-note-field"]');
    expect(rows.map(row => row.find('span').text())).toEqual([
      'Plano',
      'Risco',
    ]);
    expect(wrapper.find('[data-test="stub-plano"]').element.value).toBe('Pro');
    expect(wrapper.find('[data-test="stub-risco"]').element.value).toBe('');
  });

  it('says there are no fields yet', async () => {
    allow([]);

    const wrapper = await mountPanel();

    expect(wrapper.text()).toContain(messages.CS_NOTES.NO_FIELDS);
  });

  it('saves only the field that changed and keeps what the server answers', async () => {
    allow();
    CsNotesAPI.saveValues.mockResolvedValue({
      data: { field_values: { plano: 'Pro', risco: 'Alto' } },
    });
    const wrapper = await mountPanel();

    const input = wrapper.find('[data-test="stub-risco"]');
    input.element.value = 'Alto';
    await input.trigger('change');
    await flushPromises();

    expect(CsNotesAPI.saveValues).toHaveBeenCalledWith(10, { risco: 'Alto' });
    expect(wrapper.find('[data-test="stub-risco"]').element.value).toBe('Alto');
  });

  it('warns when a value could not be saved', async () => {
    allow();
    CsNotesAPI.saveValues.mockRejectedValue(new Error('500'));
    const wrapper = await mountPanel();

    await wrapper.find('[data-test="stub-plano"]').trigger('change');
    await flushPromises();

    expect(mocks.alert).toHaveBeenCalledWith(messages.CS_NOTES.SAVE_ERROR);
  });

  it('loads the values of the next contact', async () => {
    allow();
    const wrapper = await mountPanel();
    CsNotesAPI.getValues.mockResolvedValue({
      data: { field_values: { plano: 'Free' } },
    });

    await wrapper.setProps({ contactId: 11 });
    await flushPromises();

    expect(CsNotesAPI.getValues).toHaveBeenLastCalledWith(11);
    expect(wrapper.find('[data-test="stub-plano"]').element.value).toBe('Free');
  });

  it('opens and closes the management of the fields', async () => {
    allow();
    const wrapper = await mountPanel();

    expect(wrapper.findComponent({ name: 'CsFieldsManager' }).exists()).toBe(
      false
    );

    await wrapper.find('[data-test="cs-manage"]').trigger('click');
    expect(wrapper.findComponent({ name: 'CsFieldsManager' }).exists()).toBe(
      true
    );

    await wrapper.find('[data-test="cs-manage"]').trigger('click');
    expect(wrapper.findComponent({ name: 'CsFieldsManager' }).exists()).toBe(
      false
    );
  });
});
