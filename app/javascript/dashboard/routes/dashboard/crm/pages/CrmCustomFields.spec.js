import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { ref } from 'vue';

import { customFieldsAPI } from 'dashboard/api/crm';
import messages from 'dashboard/i18n/locale/pt_BR/crm.json';
import Component from './CrmCustomFields.vue';

vi.mock('dashboard/api/crm', () => ({
  customFieldsAPI: {
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
  },
}));

const Button = {
  inheritAttrs: false,
  props: ['label', 'disabled'],
  template:
    '<button v-bind="$attrs" :disabled="disabled"><slot />{{ label }}</button>',
};

const Input = {
  props: ['modelValue', 'label', 'placeholder', 'autofocus'],
  emits: ['update:modelValue'],
  template:
    '<label><span>{{ label }}</span><input :value="modelValue" :placeholder="placeholder" @input="$emit(\'update:modelValue\', $event.target.value)" /></label>',
};

const Checkbox = {
  props: ['modelValue'],
  emits: ['update:modelValue'],
  template:
    '<input type="checkbox" :checked="modelValue" @change="$emit(\'update:modelValue\', $event.target.checked)" />',
};

const ComboBox = {
  props: ['modelValue', 'options'],
  emits: ['update:modelValue'],
  template:
    '<select :value="modelValue" @change="$emit(\'update:modelValue\', $event.target.value)"><option v-for="option in options" :key="option.value" :value="option.value">{{ option.label }}</option></select>',
};

const Dialog = {
  props: ['title', 'confirmButtonLabel', 'cancelButtonLabel'],
  emits: ['confirm', 'close'],
  setup(_, { expose }) {
    const isOpen = ref(false);
    expose({
      open: () => {
        isOpen.value = true;
      },
      close: () => {
        isOpen.value = false;
      },
    });
    return { isOpen };
  },
  template: `
    <div v-if="isOpen" data-dialog>
      <h2>{{ title }}</h2>
      <slot />
      <button type="button" data-dialog-confirm @click="$emit('confirm')">{{ confirmButtonLabel }}</button>
      <button type="button" data-dialog-cancel @click="$emit('close')">{{ cancelButtonLabel }}</button>
    </div>
  `,
};

const fields = [
  {
    id: 1,
    key: 'lead_source',
    name: 'Origem do lead',
    field_type: 'text',
    required: false,
    active: true,
    options: [],
  },
  {
    id: 2,
    key: 'qualification',
    name: 'Qualificação',
    field_type: 'boolean',
    required: true,
    active: false,
    options: [],
  },
  {
    id: 3,
    key: 'source',
    name: 'Canal',
    field_type: 'select',
    required: false,
    active: true,
    options: ['Meta', 'Google'],
  },
];

const createWrapper = async () => {
  customFieldsAPI.get.mockResolvedValue({ data: fields });
  const wrapper = mount(Component, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: { Button, Input, Checkbox, ComboBox, Dialog },
    },
  });
  await flushPromises();
  return wrapper;
};

afterEach(() => {
  vi.clearAllMocks();
  vi.restoreAllMocks();
});

it('lists friendly types, required values and status badges', async () => {
  const wrapper = await createWrapper();

  expect(wrapper.text()).toContain('Texto curto');
  expect(wrapper.text()).toContain('Sim');
  expect(wrapper.text()).toContain('Inativo');
  expect(wrapper.text()).not.toContain('boolean');
});

it('filters fields by name and active status', async () => {
  const wrapper = await createWrapper();
  const search = wrapper.find('input[placeholder="Buscar por nome do campo"]');

  await search.setValue('canal');
  expect(wrapper.text()).toContain('Canal');
  expect(wrapper.text()).not.toContain('Origem do lead');

  await search.setValue('');
  await wrapper.findAll('select')[0].setValue('inactive');
  expect(wrapper.text()).toContain('Qualificação');
  expect(wrapper.text()).not.toContain('Origem do lead');
});

it('creates a field with the selected internal type and required value', async () => {
  const wrapper = await createWrapper();
  customFieldsAPI.create.mockResolvedValue({ data: {} });

  await wrapper.find('button').trigger('click');
  await flushPromises();
  const dialog = wrapper.find('[data-dialog]');
  const inputs = dialog.findAll('input');

  await inputs[0].setValue('Segmento');
  await dialog.findAll('select')[0].setValue('select');
  await dialog.find('input[type="checkbox"]').setValue(true);
  await dialog.find('[data-dialog-confirm]').trigger('click');
  await flushPromises();

  expect(customFieldsAPI.create).toHaveBeenCalledWith({
    custom_field: {
      name: 'Segmento',
      field_type: 'select',
      required: true,
      active: true,
      options: [],
    },
  });
});

it('loads existing values in edit mode and preserves select options', async () => {
  const wrapper = await createWrapper();

  await wrapper
    .findAll('button')
    .find(button => button.text() === 'Editar')
    .trigger('click');
  await flushPromises();

  const dialog = wrapper.find('[data-dialog]');
  expect(dialog.find('input').element.value).toBe('Origem do lead');
  expect(dialog.find('input[type="checkbox"]').element.checked).toBe(false);

  await dialog.find('input').setValue('Fonte do lead');
  await dialog.find('[data-dialog-confirm]').trigger('click');
  await flushPromises();

  expect(customFieldsAPI.update).toHaveBeenCalledWith(1, {
    custom_field: {
      name: 'Fonte do lead',
      field_type: 'text',
      required: false,
      active: true,
      options: [],
    },
  });
});

it('adds, reorders and removes options without changing their internal values', async () => {
  const wrapper = await createWrapper();
  customFieldsAPI.create.mockResolvedValue({ data: {} });

  await wrapper.find('button').trigger('click');
  await flushPromises();
  const dialog = wrapper.find('[data-dialog]');
  await dialog.findAll('input')[0].setValue('Origem');
  await dialog.findAll('select')[0].setValue('select');
  await dialog
    .findAll('button')
    .find(button => button.text() === 'Adicionar opção')
    .trigger('click');
  await dialog
    .findAll('button')
    .find(button => button.text() === 'Adicionar opção')
    .trigger('click');
  await dialog.findAll('input')[2].setValue('Google');
  await dialog.findAll('input')[3].setValue('Meta');
  await dialog
    .findAll('[aria-label="Mover opção para cima"]')[1]
    .trigger('click');
  await dialog.findAll('[aria-label="Remover opção"]')[1].trigger('click');
  await dialog.find('[data-dialog-confirm]').trigger('click');
  await flushPromises();

  expect(customFieldsAPI.create).toHaveBeenCalledWith({
    custom_field: {
      name: 'Origem',
      field_type: 'select',
      required: false,
      active: true,
      options: ['Meta'],
    },
  });
});

it('keeps select options editable and supports activation and deletion actions', async () => {
  const wrapper = await createWrapper();
  vi.spyOn(window, 'confirm').mockReturnValue(true);

  await wrapper
    .findAll('button')
    .filter(button => button.text() === 'Editar')[2]
    .trigger('click');
  await flushPromises();
  const dialog = wrapper.find('[data-dialog]');
  expect(dialog.findAll('input')[2].element.value).toBe('Meta');
  expect(dialog.findAll('input')[3].element.value).toBe('Google');

  await wrapper
    .findAll('button')
    .find(button => button.text() === 'Desativar')
    .trigger('click');
  await flushPromises();
  expect(customFieldsAPI.update).toHaveBeenCalledWith(1, {
    custom_field: { active: false },
  });

  await wrapper
    .findAll('button')
    .find(button => button.text() === 'Excluir')
    .trigger('click');
  await flushPromises();
  expect(customFieldsAPI.delete).toHaveBeenCalledWith(1);
});
