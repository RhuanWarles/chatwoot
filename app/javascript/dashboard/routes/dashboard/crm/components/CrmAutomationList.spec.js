import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import { createI18n } from 'vue-i18n';
import { createStore } from 'vuex';
import CrmAutomationList from './CrmAutomationList.vue';
import { DESTINATIONS_KEY, MAX_AUTOMATIONS } from './automationHelpers';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';

const store = createStore({
  getters: {
    'agents/getAgents': () => [{ id: 7, name: 'Maria' }],
    'labels/getLabels': () => [{ title: 'vip' }],
  },
});

let wrapper;

// Mirrors a parent using v-model:automations so updates flow back into the props.
const mountList = (automations = []) =>
  mount(CrmAutomationList, {
    props: {
      kind: 'stage',
      automations,
      'onUpdate:automations': value => wrapper.setProps({ automations: value }),
    },
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'pt_BR', messages: { pt_BR: pt } }),
        store,
      ],
      provide: { [DESTINATIONS_KEY]: ref([]) },
    },
  });

const clickButton = async (target, text) => {
  await target
    .findAll('button')
    .find(button => button.text().includes(text))
    .trigger('click');
  await flushPromises();
};

describe('CrmAutomationList', () => {
  it('adds an action from the picker', async () => {
    wrapper = mountList();
    await clickButton(wrapper, pt.CRM.AUTOMATION_ADD);
    await clickButton(wrapper, pt.CRM.AUTOMATION_TYPE_SEND_WEBHOOK);
    expect(wrapper.props('automations')).toEqual([
      { key: expect.any(String), type: 'send_webhook', url: '' },
    ]);
    expect(wrapper.find('input[inputmode="url"]').exists()).toBe(true);
  });

  it('removes an action and restores it with undo', async () => {
    const action = { key: 'a', type: 'send_webhook', url: 'https://x.com' };
    wrapper = mountList([action]);
    await wrapper.find('[aria-label="Remover ação"]').trigger('click');
    await flushPromises();
    expect(wrapper.props('automations')).toEqual([]);

    await clickButton(wrapper, pt.CRM.AUTOMATION_UNDO);
    expect(wrapper.props('automations')).toEqual([action]);
  });

  it('disables adding actions at the limit', async () => {
    wrapper = mountList(
      Array.from({ length: MAX_AUTOMATIONS }, (_, index) => ({
        key: `action-${index}`,
        type: 'send_webhook',
        url: 'https://x.com',
      }))
    );
    const addButton = wrapper
      .findAll('button')
      .find(button => button.text() === pt.CRM.AUTOMATION_ADD);
    expect(addButton.attributes('disabled')).toBeDefined();
  });
});
