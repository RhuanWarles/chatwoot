import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { ref } from 'vue';

import messages from 'dashboard/i18n/locale/pt_BR/agentMgmt.json';
import { SCREENS } from 'dashboard/helper/screenAccess';
import AddAgent from './AddAgent.vue';
import AgentAccessFields from './AgentAccessFields.vue';

const mocks = vi.hoisted(() => ({ dispatch: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: mocks.dispatch }),
  useMapGetter: name => {
    if (name === 'inboxes/getInboxes') {
      return ref([
        { id: 1, name: 'Site' },
        { id: 2, name: 'WhatsApp' },
      ]);
    }
    if (name === 'agents/getUIFlags') return ref({ isCreating: false });
    if (name === 'attributes/getAttributes') return ref([{ id: 1 }]);
    if (name === 'attributes/getAttributesByModel') {
      return ref(
        model =>
          ({
            contact_attribute: [
              { attribute_key: 'cpf', attribute_display_name: 'CPF' },
            ],
            conversation_attribute: [
              {
                attribute_key: 'origem',
                attribute_display_name: 'Origem do lead',
              },
            ],
          })[model] || []
      );
    }
    return ref([]);
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/crm', () => ({
  // A plain function: the mocks of this project are reset before every test.
  customFieldsAPI: {
    get: () =>
      Promise.resolve({
        data: [
          { key: 'renda', name: 'Renda mensal', active: true },
          { key: 'antigo', name: 'Campo antigo', active: false },
        ],
      }),
  },
}));

const TagMultiSelectComboBox = {
  props: ['modelValue', 'options'],
  emits: ['update:modelValue'],
  template:
    '<div class="inboxes"><button v-for="option in options" :key="option.value" type="button" @click="$emit(\'update:modelValue\', [...modelValue, option.value])">{{ option.label }}</button></div>',
};
const Checkbox = {
  props: ['modelValue'],
  emits: ['update:modelValue'],
  template:
    '<input type="checkbox" :checked="modelValue" @change="$emit(\'update:modelValue\', $event.target.checked)" />',
};
const Button = {
  inheritAttrs: false,
  props: ['label', 'disabled', 'type'],
  template:
    '<button v-bind="$attrs" :type="type || \'button\'" :disabled="disabled">{{ label }}</button>',
};

const global = {
  plugins: [
    createI18n({
      legacy: false,
      locale: 'pt_BR',
      messages: { pt_BR: messages },
    }),
  ],
  stubs: {
    TagMultiSelectComboBox,
    Checkbox,
    Button,
    'woot-modal-header': { template: '<div />' },
  },
};

const screenBoxes = wrapper =>
  wrapper.findAll('[data-test="screens"] input[type="checkbox"]');
const fieldBox = (wrapper, key) => wrapper.find(`[data-test="${key}"]`);

describe('AgentAccessFields', () => {
  const mountFields = props =>
    mount(AgentAccessFields, {
      props: { inboxIds: [], allowedScreens: null, ...props },
      global,
    });

  it('lists the inboxes of the account', () => {
    const wrapper = mountFields();

    expect(wrapper.findAll('.inboxes button').map(item => item.text())).toEqual(
      ['Site', 'WhatsApp']
    );
  });

  it('starts with access to every screen and no list of screens', () => {
    const wrapper = mountFields();

    expect(screenBoxes(wrapper)).toHaveLength(0);
    expect(wrapper.find('input[type="radio"]').element.checked).toBe(true);
  });

  it('starts the list with every screen ticked when the screens are chosen', async () => {
    const wrapper = mountFields();

    await wrapper.findAll('input[type="radio"]')[1].trigger('change');

    expect(wrapper.emitted('update:allowedScreens')[0][0]).toEqual(SCREENS);
  });

  it('goes back to access to every screen', async () => {
    const wrapper = mountFields({ allowedScreens: ['crm'] });

    await wrapper.findAll('input[type="radio"]')[0].trigger('change');

    expect(wrapper.emitted('update:allowedScreens')[0][0]).toBeNull();
  });

  it('removes a screen that is unticked and warns when none is left', async () => {
    const wrapper = mountFields({ allowedScreens: ['crm'] });
    const crmBox = screenBoxes(wrapper)[SCREENS.indexOf('crm')];

    expect(crmBox.element.checked).toBe(true);
    await crmBox.setValue(false);

    expect(wrapper.emitted('update:allowedScreens')[0][0]).toEqual([]);
    await wrapper.setProps({ allowedScreens: [] });
    expect(wrapper.find('[role="alert"]').text()).toContain(
      messages.AGENT_MGMT.ACCESS.SCREENS.AT_LEAST_ONE
    );
  });

  describe('fields the agent sees', () => {
    it('lists the fixed fields and the active custom fields of contacts, conversations and cards', async () => {
      const wrapper = mountFields();
      await flushPromises();

      const text = wrapper.find('[data-test="fields"]').text();
      expect(text).toContain('E-mail');
      expect(text).toContain('Telefone');
      expect(text).toContain('Valor');
      expect(text).toContain('CPF');
      expect(text).toContain('Origem do lead');
      expect(text).toContain('Renda mensal');
      expect(text).not.toContain('Campo antigo');
      expect(fieldBox(wrapper, 'contact.custom.cpf').exists()).toBe(true);
      expect(fieldBox(wrapper, 'conversation.custom.origem').exists()).toBe(
        true
      );
      expect(fieldBox(wrapper, 'deal.custom.renda').exists()).toBe(true);
    });

    it('starts with every field ticked and no list of hidden fields', async () => {
      const wrapper = mountFields();
      await flushPromises();

      const boxes = wrapper.findAll(
        '[data-test="fields"] input[type="checkbox"]'
      );
      expect(boxes.length).toBeGreaterThan(10);
      expect(boxes.every(box => box.element.checked)).toBe(true);
      expect(wrapper.emitted('update:hiddenFields')).toBeUndefined();
    });

    it('hides a field when it is unticked', async () => {
      const wrapper = mountFields();
      await flushPromises();

      await fieldBox(wrapper, 'contact.phone_number').setValue(false);

      expect(wrapper.emitted('update:hiddenFields')[0][0]).toEqual([
        'contact.phone_number',
      ]);
    });

    it('hides a custom field when it is unticked', async () => {
      const wrapper = mountFields({ hiddenFields: ['contact.email'] });
      await flushPromises();

      await fieldBox(wrapper, 'deal.custom.renda').setValue(false);

      expect(wrapper.emitted('update:hiddenFields')[0][0]).toEqual([
        'contact.email',
        'deal.custom.renda',
      ]);
    });

    it('shows the fields hidden before as unticked and ticks one back', async () => {
      const wrapper = mountFields({ hiddenFields: ['contact.email'] });
      await flushPromises();

      expect(fieldBox(wrapper, 'contact.email').element.checked).toBe(false);
      expect(fieldBox(wrapper, 'contact.company').element.checked).toBe(true);

      await fieldBox(wrapper, 'contact.email').setValue(true);

      expect(wrapper.emitted('update:hiddenFields')[0][0]).toBeNull();
    });
  });

  describe('resolving conversations', () => {
    it('is allowed by default', () => {
      const wrapper = mountFields();

      expect(fieldBox(wrapper, 'can-resolve').element.checked).toBe(true);
    });

    it('is switched off by unticking the box', async () => {
      const wrapper = mountFields();

      await fieldBox(wrapper, 'can-resolve').setValue(false);

      expect(wrapper.emitted('update:canResolveConversations')[0][0]).toBe(
        false
      );
    });
  });
});

describe('AddAgent', () => {
  const fill = async wrapper => {
    await wrapper.find('input[type="text"]').setValue('Brenda');
    await wrapper.find('input[type="email"]').setValue('brenda@example.com');
  };

  beforeEach(() => {
    vi.clearAllMocks();
    mocks.dispatch.mockResolvedValue();
  });

  it('sends the chosen inboxes with the new agent', async () => {
    const wrapper = mount(AddAgent, { global });
    await fill(wrapper);
    await wrapper.findAll('.inboxes button')[1].trigger('click');

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(mocks.dispatch).toHaveBeenCalledWith('agents/create', {
      name: 'Brenda',
      email: 'brenda@example.com',
      role: 'agent',
      inbox_ids: [2],
      can_resolve_conversations: true,
    });
  });

  it('sends the chosen screens too', async () => {
    const wrapper = mount(AddAgent, { global });
    await fill(wrapper);
    await wrapper.findAll('input[type="radio"]')[1].trigger('change');
    await screenBoxes(wrapper)[SCREENS.indexOf('inbox')].setValue(false);

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    const [, payload] = mocks.dispatch.mock.calls[0];
    expect(payload.allowed_screens).not.toContain('inbox');
    expect(payload.allowed_screens).toContain('crm');
  });

  it('sends the hidden fields and the permission to resolve too', async () => {
    const wrapper = mount(AddAgent, { global });
    await fill(wrapper);
    await flushPromises();
    await fieldBox(wrapper, 'contact.phone_number').setValue(false);
    await fieldBox(wrapper, 'can-resolve').setValue(false);

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    const [, payload] = mocks.dispatch.mock.calls[0];
    expect(payload.hidden_fields).toEqual(['contact.phone_number']);
    expect(payload.can_resolve_conversations).toBe(false);
  });

  it('does not offer inboxes or screens when the new person is an administrator', async () => {
    const wrapper = mount(AddAgent, { global });
    await fill(wrapper);
    await wrapper.find('select').setValue('administrator');

    expect(wrapper.findComponent(AgentAccessFields).exists()).toBe(false);

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    const [, payload] = mocks.dispatch.mock.calls[0];
    expect(payload).toEqual({
      name: 'Brenda',
      email: 'brenda@example.com',
      role: 'administrator',
    });
  });

  it('does not create the agent while screens are chosen but none is ticked', async () => {
    const wrapper = mount(AddAgent, { global });
    await fill(wrapper);
    await wrapper.findAll('input[type="radio"]')[1].trigger('change');
    // One click at a time, as a person would: each one has to see the list the previous one left.
    await screenBoxes(wrapper).reduce(async (previous, box) => {
      await previous;
      await box.setValue(false);
    }, Promise.resolve());

    expect(wrapper.find('button[type="submit"]').element.disabled).toBe(true);
  });
});
