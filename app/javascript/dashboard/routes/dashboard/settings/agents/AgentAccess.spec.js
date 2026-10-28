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
    return ref([]);
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

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
