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
    reorderFields: vi.fn(),
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

const Draggable = {
  name: 'Draggable',
  props: ['modelValue', 'disabled'],
  emits: ['update:modelValue'],
  template:
    '<div><slot v-for="item in modelValue" name="item" :element="item" /></div>',
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

const mountedWrappers = [];

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
      stubs: {
        Button,
        Input,
        Checkbox,
        ComboBox,
        Dialog,
        Draggable,
        TeleportWithDirection: {
          props: ['to'],
          template: '<Teleport :to="to"><slot /></Teleport>',
        },
      },
    },
  });
  await flushPromises();
  mountedWrappers.push(wrapper);
  return wrapper;
};

afterEach(() => {
  mountedWrappers.forEach(wrapper => wrapper.unmount());
  mountedWrappers.length = 0;
  document
    .querySelectorAll('[data-dropdown-menu]')
    .forEach(menu => menu.remove());
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

it('opens the actions menu through the portal and keeps only one menu open', async () => {
  const wrapper = await createWrapper();
  const menuButtons = wrapper.findAll('[aria-label="Mais ações"]');

  await menuButtons[0].trigger('click');
  await flushPromises();
  expect(document.body.querySelectorAll('[data-dropdown-menu]')).toHaveLength(
    1
  );
  expect(document.body.textContent).toContain('Desativar');
  expect(document.body.textContent).toContain('Excluir');

  await menuButtons[1].trigger('click');
  await flushPromises();
  expect(document.body.querySelectorAll('[data-dropdown-menu]')).toHaveLength(
    1
  );

  window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
  await flushPromises();
  expect(document.body.querySelectorAll('[data-dropdown-menu]')).toHaveLength(
    0
  );
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

  await wrapper.findAll('[aria-label="Mais ações"]')[0].trigger('click');
  await flushPromises();
  const disableAction = Array.from(
    document.querySelectorAll('[data-dropdown-menu] button')
  ).find(button => button.textContent === 'Desativar');
  await disableAction.click();
  await flushPromises();
  expect(customFieldsAPI.update).toHaveBeenCalledWith(1, {
    custom_field: { active: false },
  });

  await wrapper.findAll('[aria-label="Mais ações"]')[0].trigger('click');
  await flushPromises();
  const deleteAction = Array.from(
    document.querySelectorAll('[data-dropdown-menu] button')
  ).find(button => button.textContent === 'Excluir');
  await deleteAction.click();
  await flushPromises();
  expect(customFieldsAPI.delete).toHaveBeenCalledWith(1);
});

describe('reordering the fields', () => {
  const names = wrapper =>
    wrapper.findAll('[role="row"] p.font-medium').map(item => item.text());

  it('shows a drag handle on every row while nothing is filtered', async () => {
    const wrapper = await createWrapper();

    expect(wrapper.findAll('.custom-field-handle')).toHaveLength(3);
    expect(wrapper.findComponent({ name: 'Draggable' }).props('disabled')).toBe(
      false
    );
  });

  it('saves the new order after a drag and lists the fields in the order the server answers', async () => {
    const [first, second, third] = fields;
    customFieldsAPI.reorderFields.mockResolvedValue({
      data: [third, first, second],
    });
    const wrapper = await createWrapper();

    wrapper
      .findComponent({ name: 'Draggable' })
      .vm.$emit('update:modelValue', [third, first, second]);
    await flushPromises();

    expect(customFieldsAPI.reorderFields).toHaveBeenCalledWith([3, 1, 2]);
    expect(names(wrapper)).toEqual(['Canal', 'Origem do lead', 'Qualificação']);
  });

  it('shows the new order at once and restores the old one when the server refuses', async () => {
    const [first, second, third] = fields;
    let refuse;
    customFieldsAPI.reorderFields.mockReturnValue(
      new Promise((resolve, reject) => {
        refuse = reject;
      })
    );
    const wrapper = await createWrapper();

    wrapper
      .findComponent({ name: 'Draggable' })
      .vm.$emit('update:modelValue', [third, second, first]);
    await flushPromises();
    expect(names(wrapper)).toEqual(['Canal', 'Qualificação', 'Origem do lead']);

    refuse(new Error('500'));
    await flushPromises();

    expect(names(wrapper)).toEqual(['Origem do lead', 'Qualificação', 'Canal']);
    expect(wrapper.text()).toContain(messages.CRM.CF_REORDER_ERROR);
  });

  it('does not allow dragging while the list is filtered', async () => {
    const wrapper = await createWrapper();

    await wrapper
      .find(
        `input[placeholder="${messages.CRM.CUSTOM_FIELD_SEARCH_PLACEHOLDER}"]`
      )
      .setValue('Canal');

    expect(wrapper.findComponent({ name: 'Draggable' }).props('disabled')).toBe(
      true
    );
    expect(wrapper.findAll('.custom-field-handle')).toHaveLength(0);

    wrapper
      .findComponent({ name: 'Draggable' })
      .vm.$emit('update:modelValue', [fields[2]]);
    await flushPromises();
    expect(customFieldsAPI.reorderFields).not.toHaveBeenCalled();
  });
});
