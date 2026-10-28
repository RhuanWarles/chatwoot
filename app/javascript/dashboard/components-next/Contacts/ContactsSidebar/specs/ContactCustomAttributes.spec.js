import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import { createI18n } from 'vue-i18n';

import messages from 'dashboard/i18n/locale/pt_BR/contact.json';
import ContactCustomAttributes from '../ContactCustomAttributes.vue';

const ORDER_KEY = 'conversation_elements_order_conversation_contact_panel';
const attributes = [
  { id: 1, attributeKey: 'plan', attributeDisplayName: 'Plano' },
  { id: 2, attributeKey: 'city', attributeDisplayName: 'Cidade' },
  { id: 3, attributeKey: 'cpf', attributeDisplayName: 'CPF' },
  { id: 4, attributeKey: 'company', attributeDisplayName: 'Empresa' },
];

const mocks = vi.hoisted(() => ({ updateUISettings: vi.fn() }));
let savedOrder;
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: { value: { [ORDER_KEY]: savedOrder } },
    updateUISettings: mocks.updateUISettings,
  }),
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref(attributes),
}));

const Draggable = {
  name: 'Draggable',
  props: ['modelValue', 'disabled'],
  emits: ['update:modelValue'],
  template:
    '<div><slot v-for="item in modelValue" name="item" :element="item" /></div>',
};
const Item = {
  props: ['attribute'],
  template: '<span data-item>{{ attribute.attributeDisplayName }}</span>',
};

const mountList = () =>
  mount(ContactCustomAttributes, {
    props: {
      // plan and city have a value in this contact; cpf and company do not.
      selectedContact: { customAttributes: { plan: 'Pro', city: 'Goiânia' } },
    },
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: { Draggable, ContactCustomAttributeItem: Item },
    },
  });

const draggables = wrapper => wrapper.findAllComponents({ name: 'Draggable' });
const names = list => list.findAll('[data-item]').map(item => item.text());

beforeEach(() => {
  vi.clearAllMocks();
  savedOrder = undefined;
});

describe('ContactCustomAttributes ordering', () => {
  it('lists the attributes with a value and the ones without, each with a drag handle', () => {
    const wrapper = mountList();
    const [used, unused] = draggables(wrapper);

    expect(names(used)).toEqual(['Plano', 'Cidade']);
    expect(names(unused)).toEqual(['CPF', 'Empresa']);
    expect(wrapper.findAll('.attribute-drag-handle')).toHaveLength(4);
  });

  it('follows the order saved for the conversation sidebar', () => {
    savedOrder = ['city', 'company', 'plan', 'cpf'];
    const wrapper = mountList();
    const [used, unused] = draggables(wrapper);

    expect(names(used)).toEqual(['Cidade', 'Plano']);
    expect(names(unused)).toEqual(['Empresa', 'CPF']);
  });

  it('saves the new order of the attributes with a value, in the places they had', () => {
    savedOrder = ['plan', 'cpf', 'city', 'company'];
    const wrapper = mountList();
    const [used] = draggables(wrapper);

    used.vm.$emit('update:modelValue', [
      attributes[1], // city
      attributes[0], // plan
    ]);

    expect(mocks.updateUISettings).toHaveBeenCalledWith({
      [ORDER_KEY]: ['city', 'cpf', 'plan', 'company'],
    });
  });

  it('saves the order of the attributes without a value too', () => {
    savedOrder = ['plan', 'city', 'cpf', 'company'];
    const wrapper = mountList();
    const [, unused] = draggables(wrapper);

    unused.vm.$emit('update:modelValue', [attributes[3], attributes[2]]);

    expect(mocks.updateUISettings).toHaveBeenCalledWith({
      [ORDER_KEY]: ['plan', 'city', 'company', 'cpf'],
    });
  });

  it('keeps the static elements of the conversation sidebar in the saved order', () => {
    savedOrder = ['static-contact-info', 'plan', 'city', 'cpf', 'company'];
    const wrapper = mountList();
    const [used] = draggables(wrapper);

    used.vm.$emit('update:modelValue', [attributes[1], attributes[0]]);

    expect(mocks.updateUISettings).toHaveBeenCalledWith({
      [ORDER_KEY]: ['city', 'static-contact-info', 'plan', 'cpf', 'company'],
    });
  });

  it('does not allow dragging the unused list while it is being searched', async () => {
    const wrapper = mountList();
    await wrapper.find('input[type="search"]').setValue('CP');
    const [, unused] = draggables(wrapper);

    expect(unused.props('disabled')).toBe(true);
    expect(names(unused)).toEqual(['CPF']);
    expect(
      wrapper.findAll('[data-test="unused-attribute"] .attribute-drag-handle')
    ).toHaveLength(0);
  });
});
