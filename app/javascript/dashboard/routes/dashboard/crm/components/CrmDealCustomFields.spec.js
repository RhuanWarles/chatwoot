import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { dealsAPI } from 'dashboard/api/crm';
import Component from './CrmDealCustomFields.vue';
import messages from 'dashboard/i18n/locale/pt_BR/crm.json';

vi.mock('dashboard/api/crm', () => ({
  dealsAPI: {
    customFields: vi.fn(),
    updateCustomFields: vi.fn(),
    update: vi.fn(),
  },
}));
const Button = {
  props: ['label', 'disabled', 'isLoading'],
  template: '<button :disabled="disabled">{{ label }}</button>',
};
const Input = {
  props: ['modelValue', 'type', 'id', 'disabled'],
  emits: ['update:modelValue'],
  template:
    '<input :id="id" :type="type" :value="modelValue" :disabled="disabled" @input="$emit(\'update:modelValue\', $event.target.value)" />',
};
const Currency = {
  props: ['modelValue'],
  emits: ['update:modelValue'],
  setup() {
    return { isInvalid: false };
  },
  template:
    '<input data-currency :value="modelValue" @input="$emit(\'update:modelValue\', Number($event.target.value))" />',
};
const definitions = [
  ['text', null],
  ['textarea', 'Long'],
  ['number', 35],
  ['currency', 120],
  ['date', '2026-10-10'],
  ['datetime', '2026-10-10T15:00:00Z'],
  ['boolean', false],
  ['select', 'Meta'],
  ['multiselect', ['Meta']],
].map(([field_type, value], index) => ({
  id: index + 1,
  key: field_type,
  name: field_type,
  field_type,
  value,
  options: ['Meta', 'Google'],
  required: false,
  active: true,
  position: index,
}));
const create = async (fields = definitions, deal = null) => {
  dealsAPI.customFields.mockResolvedValue({ data: fields });
  const wrapper = mount(Component, {
    props: { dealId: 12, deal },
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: { Button, Input, CrmCurrencyInput: Currency },
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

it('shows every active definition returned by account endpoint, including empty values and API order', async () => {
  const wrapper = await create();
  expect(dealsAPI.customFields).toHaveBeenCalledWith(12);
  expect(wrapper.findAll('dt').map(item => item.text())).toEqual(
    definitions.map(item => item.name)
  );
  expect(wrapper.text()).toContain(messages.CRM.NOT_SET);
  expect(wrapper.text()).toContain('R$');
  expect(wrapper.text()).not.toContain('undefined');
});
it('renders all nine field types and preloads their values', async () => {
  const wrapper = await create();
  await click(wrapper, messages.CRM.EDIT);
  expect(wrapper.find('input[type=text]').exists()).toBe(true);
  expect(wrapper.find('textarea').element.value).toBe('Long');
  expect(wrapper.find('input[type=number]').element.value).toBe('35');
  expect(wrapper.find('[data-currency]').exists()).toBe(true);
  expect(wrapper.find('input[type=date]').element.value).toBe('2026-10-10');
  expect(wrapper.find('input[type=datetime-local]').element.value).not.toBe('');
  expect(wrapper.find('input[type=checkbox]').element.checked).toBe(false);
  expect(wrapper.find('select:not([multiple])').element.value).toBe('Meta');
  expect(wrapper.find('select[multiple]').exists()).toBe(true);
});
it('sends only changed values in one batch, preserving numeric and array types', async () => {
  const wrapper = await create();
  dealsAPI.updateCustomFields.mockResolvedValue({ data: definitions });
  await click(wrapper, messages.CRM.EDIT);
  await wrapper.find('input[type=text]').setValue('City');
  await wrapper.find('input[type=number]').setValue('42');
  await wrapper.find('select[multiple]').setValue(['Google']);
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(dealsAPI.updateCustomFields).toHaveBeenCalledWith(12, {
    text: 'City',
    number: 42,
    multiselect: ['Google'],
  });
  expect(wrapper.emitted('changed')).toHaveLength(1);
});
it('clears an existing value with null', async () => {
  const wrapper = await create([{ ...definitions[0], value: 'City' }]);
  dealsAPI.updateCustomFields.mockResolvedValue({
    data: [{ ...definitions[0], value: null }],
  });
  await click(wrapper, messages.CRM.EDIT);
  await wrapper.find('input').setValue('');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(dealsAPI.updateCustomFields).toHaveBeenCalledWith(12, { text: null });
});
it('does not submit unchanged values or emit history refresh', async () => {
  const wrapper = await create();
  await click(wrapper, messages.CRM.EDIT);
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(dealsAPI.updateCustomFields).not.toHaveBeenCalled();
  expect(wrapper.emitted('changed')).toBeUndefined();
});
it('validates required fields and preserves draft after server error', async () => {
  const wrapper = await create([{ ...definitions[0], required: true }]);
  await click(wrapper, messages.CRM.EDIT);
  await wrapper.find('form').trigger('submit');
  expect(dealsAPI.updateCustomFields).not.toHaveBeenCalled();
  await wrapper.find('input').setValue('City');
  dealsAPI.updateCustomFields.mockRejectedValue({
    response: { data: { error: 'Falha' } },
  });
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(wrapper.find('input').element.value).toBe('City');
  expect(wrapper.find('[role=alert]').text()).toBe('Falha');
});
it('cancels without requests and can reopen with saved values', async () => {
  const wrapper = await create();
  await click(wrapper, messages.CRM.EDIT);
  await wrapper.find('input[type=text]').setValue('Draft');
  await click(wrapper, messages.CRM.CF_CANCEL);
  await click(wrapper, messages.CRM.EDIT);
  expect(wrapper.find('input[type=text]').element.value).toBe('');
  expect(dealsAPI.updateCustomFields).not.toHaveBeenCalled();
});

it('collapses and expands Details without discarding an edit draft', async () => {
  const wrapper = await create();
  const toggle = wrapper.find('[aria-controls]');
  await toggle.trigger('click');
  expect(toggle.attributes('aria-expanded')).toBe('false');
  await toggle.trigger('click');
  expect(toggle.attributes('aria-expanded')).toBe('true');
  await click(wrapper, messages.CRM.EDIT);
  await wrapper.find('input[type=text]').setValue('Draft');
  await toggle.trigger('click');
  await toggle.trigger('click');
  expect(wrapper.find('input[type=text]').element.value).toBe('Draft');
});

it('keeps native and custom details in one list and edits only changed native fields', async () => {
  const deal = { id: 12, name: 'Original', description: 'Description' };
  const wrapper = await create(definitions, deal);
  expect(wrapper.findAll('dl')).toHaveLength(1);
  expect(
    wrapper
      .findAll('dt')
      .slice(0, 2)
      .map(item => item.text())
  ).toEqual([messages.CRM.NAME, messages.CRM.DESCRIPTION]);
  expect(wrapper.text()).not.toContain(messages.CRM.CUSTOM_FIELDS_TITLE);
  dealsAPI.update.mockResolvedValue({ data: { ...deal, name: 'Changed' } });
  await click(wrapper, messages.CRM.EDIT);
  await wrapper.find('#deal-details-name').setValue('Changed');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(dealsAPI.update).toHaveBeenCalledWith(12, {
    deal: { name: 'Changed' },
  });
  expect(dealsAPI.updateCustomFields).not.toHaveBeenCalled();
  expect(wrapper.emitted('dealUpdated')[0][0].name).toBe('Changed');
});

it('preserves native fields on cancel and renders Details even without custom fields', async () => {
  const wrapper = await create([], { name: 'Original', description: '' });
  await click(wrapper, messages.CRM.EDIT);
  await wrapper.find('#deal-details-name').setValue('Draft');
  await click(wrapper, messages.CRM.CF_CANCEL);
  await click(wrapper, messages.CRM.EDIT);
  expect(wrapper.find('#deal-details-name').element.value).toBe('Original');
  expect(dealsAPI.update).not.toHaveBeenCalled();
});

it('preserves the entire draft when saving native details fails', async () => {
  const wrapper = await create(definitions, {
    name: 'Original',
    description: '',
  });
  dealsAPI.update.mockRejectedValue(new Error('Failed'));
  await click(wrapper, messages.CRM.EDIT);
  await wrapper.find('#deal-details-name').setValue('Changed');
  await wrapper.find('#cf-1').setValue('City');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(wrapper.find('#deal-details-name').element.value).toBe('Changed');
  expect(wrapper.find('#cf-1').element.value).toBe('City');
  expect(wrapper.find('[role=alert]').exists()).toBe(true);
  expect(dealsAPI.updateCustomFields).not.toHaveBeenCalled();
});

it('renders many fields in a single compact column and wraps multiselect chips', async () => {
  const many = Array.from({ length: 50 }, (_, index) => ({
    ...definitions[8],
    id: index + 1,
    key: 'field-' + index,
    name: 'Field ' + index,
    value: ['Meta', 'Google'],
  }));
  const wrapper = await create(many);
  expect(wrapper.findAll('dt')).toHaveLength(50);
  expect(wrapper.find('dl').classes()).toContain('flex-col');
  expect(wrapper.find('dd > div').classes()).toContain('flex-wrap');
  expect(wrapper.text()).not.toContain('["Meta"');
});

it('allows an empty boolean to become an explicit false without overwriting other fields', async () => {
  const wrapper = await create([{ ...definitions[6], value: null }]);
  dealsAPI.updateCustomFields.mockResolvedValue({
    data: [{ ...definitions[6], value: false }],
  });
  await click(wrapper, messages.CRM.EDIT);
  await wrapper.find('input[type=checkbox]').setValue(true);
  await wrapper.find('input[type=checkbox]').setValue(false);
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(dealsAPI.updateCustomFields).toHaveBeenCalledWith(12, {
    boolean: false,
  });
});
