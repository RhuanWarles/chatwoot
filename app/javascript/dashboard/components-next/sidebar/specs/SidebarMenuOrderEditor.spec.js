import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';

import messages from 'dashboard/i18n/locale/pt_BR/settings.json';
import SidebarMenuOrderEditor from '../SidebarMenuOrderEditor.vue';

const mocks = vi.hoisted(() => ({ isAllowed: vi.fn(() => true) }));
vi.mock('../provider', () => ({
  useSidebarContext: () => ({ isAllowed: mocks.isAllowed }),
}));

const route = name => ({ name, params: {} });
const items = [
  { name: 'Inbox', label: 'Caixa', icon: 'i-lucide-inbox', to: route('inbox') },
  {
    name: 'Contacts',
    label: 'Contatos',
    icon: 'i-lucide-contact',
    children: [{ name: 'All', label: 'Todos', to: route('contacts') }],
  },
  { name: 'Settings', label: 'Configurações', children: [] },
  {
    name: 'CRM',
    label: 'CRM',
    icon: 'i-lucide-kanban-square',
    to: route('crm'),
  },
];

const mountEditor = (props = {}) =>
  mount(SidebarMenuOrderEditor, {
    props: { items, ...props },
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: {
        Icon: true,
        Draggable: {
          template:
            '<div><slot name="item" v-for="(element, index) in modelValue" :element="element" :index="index" /></div>',
          props: ['modelValue'],
        },
      },
    },
  });

const labels = wrapper =>
  wrapper.findAll('[data-test="menu-order-item"]').map(row => row.text());

beforeEach(() => {
  mocks.isAllowed.mockReturnValue(true);
});

describe('SidebarMenuOrderEditor', () => {
  it('lists only the tabs the person can open', () => {
    const wrapper = mountEditor();

    // "Configurações" has nothing inside it, so the sidebar does not show it either
    expect(labels(wrapper)).toEqual(['Caixa', 'Contatos', 'CRM']);
  });

  it('hides a tab whose pages are all closed to the person', () => {
    mocks.isAllowed.mockImplementation(to => to.name !== 'contacts');

    expect(labels(mountEditor())).toEqual(['Caixa', 'CRM']);
  });

  it('sends the new order when a tab goes down', async () => {
    const wrapper = mountEditor();

    await wrapper.findAll('[data-test="menu-order-down"]')[0].trigger('click');

    expect(wrapper.emitted('change')[0][0]).toEqual([
      'Contacts',
      'Inbox',
      'CRM',
    ]);
    expect(labels(wrapper)).toEqual(['Contatos', 'Caixa', 'CRM']);
  });

  it('cannot move the first tab up nor the last one down', () => {
    const wrapper = mountEditor();

    const up = wrapper.findAll('[data-test="menu-order-up"]');
    const down = wrapper.findAll('[data-test="menu-order-down"]');

    expect(up[0].attributes('disabled')).toBeDefined();
    expect(down[down.length - 1].attributes('disabled')).toBeDefined();
  });

  it('asks to restore the default order and to finish', async () => {
    const wrapper = mountEditor();

    await wrapper.find('[data-test="menu-order-reset"]').trigger('click');
    await wrapper.find('[data-test="menu-order-done"]').trigger('click');

    expect(wrapper.emitted('reset')).toHaveLength(1);
    expect(wrapper.emitted('done')).toHaveLength(1);
  });
});
