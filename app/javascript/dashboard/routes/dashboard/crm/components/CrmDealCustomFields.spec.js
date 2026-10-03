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
const create = async (fields = definitions) => {
  dealsAPI.customFields.mockResolvedValue({ data: fields });
  const wrapper = mount(Component, {
    props: { dealId: 12 },
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

it('lists only custom fields in API order, with clickable empty values and no general editor', async () => {
  const wrapper = await create();
  expect(dealsAPI.customFields).toHaveBeenCalledWith(12);
  expect(
    wrapper.findAll('[id^="cf-read-"]').map(item => item.find('span').text())
  ).toEqual(definitions.map(item => item.name));
  expect(wrapper.text()).toContain(messages.CRM.NOT_SET);
  expect(wrapper.text()).not.toContain(messages.CRM.NAME);
  expect(wrapper.text()).not.toContain(messages.CRM.DESCRIPTION);
  expect(
    wrapper.findAll('button').some(item => item.text() === messages.CRM.EDIT)
  ).toBe(false);
  expect(wrapper.find('#cf-read-1').classes()).toContain('hover:bg-n-alpha-2');
});

it.each(definitions)(
  'edits only the selected $field_type field with its native editor',
  async field => {
    const wrapper = await create();
    await wrapper.find('#cf-read-' + field.id).trigger('click');
    await flushPromises();
    expect(wrapper.findAll('form')).toHaveLength(1);
    expect(wrapper.findAll('[id^="cf-read-"]')).toHaveLength(8);
    expect(wrapper.find('input[type=checkbox]').exists()).toBe(false);
    if (field.field_type === 'boolean') {
      expect(wrapper.findAll('input[type=radio]')).toHaveLength(2);
      expect(wrapper.findAll('input[type=radio]')[1].element.checked).toBe(
        true
      );
    } else if (field.field_type === 'textarea')
      expect(wrapper.find('textarea').element.value).toBe('Long');
    else if (field.field_type === 'currency')
      expect(wrapper.find('[data-currency]').element.value).toBe('120');
    else if (field.field_type === 'multiselect')
      expect(wrapper.find('select[multiple]').exists()).toBe(true);
    else if (field.field_type === 'select')
      expect(wrapper.find('select').element.value).toBe('Meta');
    else expect(wrapper.find('#cf-' + field.id).exists()).toBe(true);
  }
);

it('persists exactly one changed key and refreshes its display and timeline', async () => {
  const wrapper = await create();
  dealsAPI.updateCustomFields.mockResolvedValue({
    data: definitions.map(field =>
      field.key === 'text' ? { ...field, value: 'City' } : field
    ),
  });
  await wrapper.find('#cf-read-1').trigger('click');
  await wrapper.find('#cf-1').setValue('City');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(dealsAPI.updateCustomFields).toHaveBeenCalledWith(12, {
    text: 'City',
  });
  expect(wrapper.find('#cf-read-1').text()).toContain('City');
  expect(wrapper.find('#cf-read-3').text()).toContain('35');
  expect(wrapper.emitted('changed')).toHaveLength(1);
  expect(dealsAPI.update).not.toHaveBeenCalled();
});

it('saves false as a boolean using the No radio, even for an empty required field', async () => {
  const field = { ...definitions[6], value: null, required: true };
  const wrapper = await create([field]);
  dealsAPI.updateCustomFields.mockResolvedValue({
    data: [{ ...field, value: false }],
  });
  await wrapper.find('#cf-read-7').trigger('click');
  await wrapper.findAll('input[type=radio]')[1].setValue(true);
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(dealsAPI.updateCustomFields).toHaveBeenCalledWith(12, {
    boolean: false,
  });
  expect(wrapper.text()).toContain(messages.CRM.CF_NO);
});

it.each([
  ['number', '#cf-3', '42', 42],
  ['currency', '[data-currency]', '2500', 2500],
  ['multiselect', 'select[multiple]', ['Google'], ['Google']],
  ['text', '#cf-1', '', null],
])(
  'preserves the API value type when editing %s',
  async (key, selector, value, expected) => {
    const field = { ...definitions.find(item => item.key === key) };
    if (key === 'text') field.value = 'Original';
    const wrapper = await create([field]);
    dealsAPI.updateCustomFields.mockResolvedValue({
      data: [{ ...field, value: expected }],
    });
    await wrapper.find('#cf-read-' + field.id).trigger('click');
    await wrapper.find(selector).setValue(value);
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(dealsAPI.updateCustomFields).toHaveBeenCalledWith(12, {
      [key]: expected,
    });
  }
);

it('cancels a field and restores its saved value when reopened', async () => {
  const wrapper = await create();
  await wrapper.find('#cf-read-1').trigger('click');
  await wrapper.find('#cf-1').setValue('Draft');
  await click(wrapper, messages.CRM.CF_CANCEL);
  expect(wrapper.findAll('form')).toHaveLength(0);
  await wrapper.find('#cf-read-1').trigger('click');
  expect(wrapper.find('#cf-1').element.value).toBe('');
  expect(dealsAPI.updateCustomFields).not.toHaveBeenCalled();
});

it('validates required whitespace and retains the selected draft on API failure', async () => {
  const wrapper = await create([{ ...definitions[0], required: true }]);
  await wrapper.find('#cf-read-1').trigger('click');
  await wrapper.find('#cf-1').setValue('   ');
  await wrapper.find('form').trigger('submit');
  expect(dealsAPI.updateCustomFields).not.toHaveBeenCalled();
  await wrapper.find('#cf-1').setValue('City');
  dealsAPI.updateCustomFields.mockRejectedValue({
    response: { data: { error: 'Falha' } },
  });
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(wrapper.find('#cf-1').element.value).toBe('City');
  expect(wrapper.find('[role=alert]').text()).toBe('Falha');
});

it('does not resend unchanged values, including a datetime, or refresh history', async () => {
  const wrapper = await create();
  await wrapper.find('#cf-read-6').trigger('click');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
  expect(dealsAPI.updateCustomFields).not.toHaveBeenCalled();
  expect(wrapper.emitted('changed')).toBeUndefined();
});

it('keeps one editor when switching fields and preserves a draft while collapsing Details', async () => {
  const wrapper = await create();
  await wrapper.find('#cf-read-1').trigger('click');
  await wrapper.find('#cf-1').setValue('Draft');
  await wrapper.find('[aria-controls]').trigger('click');
  await wrapper.find('[aria-controls]').trigger('click');
  expect(wrapper.find('#cf-1').element.value).toBe('Draft');
  await wrapper.find('#cf-read-3').trigger('click');
  expect(wrapper.findAll('form')).toHaveLength(1);
  expect(wrapper.find('#cf-3').element.value).toBe('35');
  expect(wrapper.find('#cf-read-1').text()).toContain(messages.CRM.NOT_SET);
});

it('expands a long textarea without opening its editor, then opens inline on the value', async () => {
  const field = { ...definitions[1], value: 'Long content. '.repeat(40) };
  const wrapper = await create([field]);
  expect(wrapper.find('#cf-read-2 > span:last-child').classes()).toContain(
    'line-clamp-3'
  );
  await click(wrapper, messages.CRM.SIDEBAR_MORE);
  expect(wrapper.find('form').exists()).toBe(false);
  expect(wrapper.find('#cf-read-2 > span:last-child').classes()).not.toContain(
    'line-clamp-3'
  );
  await click(wrapper, messages.CRM.SIDEBAR_LESS);
  await wrapper.find('#cf-read-2').trigger('click');
  expect(wrapper.find('textarea').element.value).toBe(field.value);
});

it('wraps multiselect chips without rendering raw JSON and renders many fields', async () => {
  const fields = Array.from({ length: 50 }, (_, i) => ({
    ...definitions[8],
    id: i + 1,
    key: 'key' + i,
    value: ['Meta', 'Google'],
  }));
  const wrapper = await create(fields);
  expect(wrapper.findAll('[id^="cf-read-"]')).toHaveLength(50);
  expect(wrapper.find('#cf-read-1 > span:last-child').classes()).toContain(
    'flex-wrap'
  );
  expect(wrapper.text()).not.toContain('["Meta"');
});

it('prevents duplicate saves and editing another field while the request is pending', async () => {
  const wrapper = await create();
  let finish;
  dealsAPI.updateCustomFields.mockImplementation(
    () =>
      new Promise(resolve => {
        finish = resolve;
      })
  );
  await wrapper.find('#cf-read-1').trigger('click');
  await wrapper.find('#cf-1').setValue('City');
  await wrapper.find('form').trigger('submit');
  await wrapper.find('form').trigger('submit');
  expect(dealsAPI.updateCustomFields).toHaveBeenCalledTimes(1);
  expect(wrapper.find('#cf-read-3').attributes('disabled')).toBeDefined();
  finish({ data: definitions });
  await flushPromises();
});
