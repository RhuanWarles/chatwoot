import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';

import messages from 'dashboard/i18n/locale/pt_BR/contact.json';
import CsNotesAPI from 'dashboard/api/csNotes';
import { resetCsNotes, useCsNotes } from 'dashboard/composables/useCsNotes';
import CsFieldsManager from '../CsFieldsManager.vue';

const mocks = vi.hoisted(() => ({ alert: vi.fn() }));
vi.mock('dashboard/composables', () => ({ useAlert: mocks.alert }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({
    value: [
      { id: 4, name: 'Customer Success' },
      { id: 5, name: 'Vendas' },
    ],
  }),
}));
vi.mock('dashboard/api/csNotes', () => ({
  default: {
    getSettings: vi.fn(),
    updateSettings: vi.fn(),
    createField: vi.fn(),
    updateField: vi.fn(),
    deleteField: vi.fn(),
  },
}));

const plan = {
  id: 1,
  attribute_key: 'plano',
  attribute_display_name: 'Plano',
  attribute_display_type: 'text',
};

const mountManager = async ({ canManage = true } = {}) => {
  CsNotesAPI.getSettings.mockResolvedValue({
    data: {
      can_access: true,
      can_manage: canManage,
      team_id: canManage ? 4 : undefined,
      fields: [plan],
    },
  });
  await useCsNotes().load();

  return mount(CsFieldsManager, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
    },
  });
};

const find = (wrapper, name) => wrapper.find(`[data-test="${name}"]`);

beforeEach(() => {
  vi.clearAllMocks();
  resetCsNotes();
});

describe('CsFieldsManager', () => {
  it('lets an administrator choose the team in charge', async () => {
    CsNotesAPI.updateSettings.mockResolvedValue({
      data: { can_access: true, can_manage: true, team_id: 5, fields: [plan] },
    });
    const wrapper = await mountManager();

    const select = find(wrapper, 'cs-team-select').find('select');
    expect(select.element.value).toBe('4');
    await select.setValue('5');
    await flushPromises();

    expect(CsNotesAPI.updateSettings).toHaveBeenCalledWith(5);
  });

  it('turns the team off when "only administrators" is chosen', async () => {
    CsNotesAPI.updateSettings.mockResolvedValue({
      data: { can_access: true, can_manage: true, team_id: null, fields: [] },
    });
    const wrapper = await mountManager();

    await find(wrapper, 'cs-team-select').find('select').setValue('');
    await flushPromises();

    expect(CsNotesAPI.updateSettings).toHaveBeenCalledWith(null);
  });

  it('does not show the team to someone who is not an administrator', async () => {
    const wrapper = await mountManager({ canManage: false });

    expect(find(wrapper, 'cs-team-select').exists()).toBe(false);
    expect(find(wrapper, 'cs-add-field').exists()).toBe(true);
  });

  it('adds a field of the chosen type', async () => {
    CsNotesAPI.createField.mockResolvedValue({
      data: { ...plan, id: 2, attribute_key: 'renovacao' },
    });
    const wrapper = await mountManager();

    expect(find(wrapper, 'cs-add-field').attributes('disabled')).toBeDefined();
    await find(wrapper, 'cs-new-name').find('input').setValue('Renovação');
    await find(wrapper, 'cs-new-type').find('select').setValue('date');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(CsNotesAPI.createField).toHaveBeenCalledWith({
      attribute_display_name: 'Renovação',
      attribute_display_type: 'date',
    });
    expect(wrapper.findAll('[data-test="cs-field-row"]')).toHaveLength(2);
    expect(find(wrapper, 'cs-new-name').find('input').element.value).toBe('');
  });

  it('asks for the options of a list before adding it', async () => {
    CsNotesAPI.createField.mockResolvedValue({
      data: { ...plan, id: 2, attribute_display_type: 'list' },
    });
    const wrapper = await mountManager();

    await find(wrapper, 'cs-new-name').find('input').setValue('Risco');
    await find(wrapper, 'cs-new-type').find('select').setValue('list');
    expect(find(wrapper, 'cs-add-field').attributes('disabled')).toBeDefined();

    await find(wrapper, 'cs-new-options')
      .find('textarea')
      .setValue('Baixo\n  Alto \n\n');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(CsNotesAPI.createField).toHaveBeenCalledWith({
      attribute_display_name: 'Risco',
      attribute_display_type: 'list',
      attribute_values: ['Baixo', 'Alto'],
    });
  });

  it('warns when the field could not be created', async () => {
    CsNotesAPI.createField.mockRejectedValue(new Error('422'));
    const wrapper = await mountManager();

    await find(wrapper, 'cs-new-name').find('input').setValue('Plano');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(mocks.alert).toHaveBeenCalledWith(messages.CS_NOTES.ADD_ERROR);
  });

  it('asks to confirm before deleting a field', async () => {
    CsNotesAPI.deleteField.mockResolvedValue({});
    const wrapper = await mountManager();

    await find(wrapper, 'cs-field-delete').trigger('click');
    expect(CsNotesAPI.deleteField).not.toHaveBeenCalled();

    await find(wrapper, 'cs-field-delete-confirm').trigger('click');
    await flushPromises();

    expect(CsNotesAPI.deleteField).toHaveBeenCalledWith(1);
    expect(wrapper.findAll('[data-test="cs-field-row"]')).toHaveLength(0);
  });

  it('renames a field when the person leaves its name', async () => {
    CsNotesAPI.updateField.mockResolvedValue({
      data: { ...plan, attribute_display_name: 'Plano atual' },
    });
    const wrapper = await mountManager();

    const input = find(wrapper, 'cs-field-name-plano').find('input');
    await input.setValue('Plano atual');
    await input.trigger('blur');
    await flushPromises();

    expect(CsNotesAPI.updateField).toHaveBeenCalledWith(1, {
      attribute_display_name: 'Plano atual',
    });
  });
});
