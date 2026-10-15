import { mount, flushPromises } from '@vue/test-utils';
import MessageReactions from '../MessageReactions.vue';
import messageReactionsAPI from 'dashboard/api/conversations/messageReactionsAPI';
import { useAlert } from 'dashboard/composables';

vi.mock('dashboard/api/conversations/messageReactionsAPI', () => ({
  default: { react: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values) =>
      key === 'MESSAGE_REACTIONS.COUNT'
        ? `${values.emoji} ${values.count}`
        : key,
  }),
}));
vi.mock('dashboard/components-next/button/Button.vue', () => ({
  default: {
    props: ['label', 'disabled'],
    template:
      '<button :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
  },
}));
vi.mock('dashboard/components-next/avatar/Avatar.vue', () => ({
  default: { template: '<span />' },
}));
vi.mock('dashboard/components-next/popover/Popover.vue', () => ({
  default: {
    template:
      '<div><slot :is-open="true" /><div><slot name="content" /></div></div>',
    methods: { show() {}, hide() {} },
  },
}));
vi.mock(
  'dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue',
  () => ({
    default: {
      props: ['showRemoveButton'],
      template:
        '<div data-testid="emoji-picker"><button aria-label="🧑🏽‍💻" @click="$emit(\'select\', { value: \'🧑🏽‍💻\' })">🧑🏽‍💻</button><button v-if="showRemoveButton" aria-label="Remove my reaction" @click="$emit(\'remove\')">Remove my reaction</button></div>',
    },
  })
);
vi.mock('dashboard/components-next/dialog/Dialog.vue', () => ({
  default: {
    name: 'Dialog',
    props: ['title'],
    data: () => ({ opened: false }),
    methods: {
      open() {
        this.opened = true;
      },
      close() {
        this.opened = false;
      },
    },
    template: '<section v-if="opened"><h2>{{ title }}</h2><slot /></section>',
  },
}));

describe('Message reactions', () => {
  let wrapper;
  // jsdom's CSS selector engine mishandles astral emoji in attribute selectors.
  const findButton = label =>
    wrapper
      .findAll('button')
      .find(button => button.attributes('aria-label') === label);
  const own = {
    participant_key: 'self',
    from_me: true,
    user_id: 7,
    display_name: 'Operator',
    emoji: '👍',
  };
  const participant = {
    participant_key: 'contact',
    from_me: false,
    display_name: 'Contact',
    emoji: '👍',
  };

  beforeEach(() => {
    messageReactionsAPI.react.mockResolvedValue({
      data: { reactions: [own, participant] },
    });
    wrapper = mount(MessageReactions, {
      props: {
        messageId: 12,
        conversationId: 36,
        currentUserId: 7,
        reactions: [own, participant],
      },
      global: { directives: { 'on-click-outside': {} } },
    });
  });
  afterEach(() => wrapper.unmount());

  it('groups participants by emoji and opens the list of names', async () => {
    expect(findButton('👍 2')).toBeTruthy();
    await findButton('👍 2').trigger('click');
    expect(wrapper.text()).toContain('Operator');
    expect(wrapper.text()).toContain('Contact');
  });

  it('shows separate chips and updates them from realtime props', async () => {
    await wrapper.setProps({
      reactions: [own, { ...participant, emoji: '❤️' }],
    });
    expect(findButton('👍 1')).toBeTruthy();
    expect(findButton('❤️ 1')).toBeTruthy();
    await wrapper.setProps({ reactions: [{ ...participant, emoji: '' }] });
    expect(findButton('👍 1')).toBeUndefined();
  });

  it('shows the new emoji optimistically and sends the actual message and conversation ids', async () => {
    let resolve;
    messageReactionsAPI.react.mockReturnValue(
      new Promise(done => {
        resolve = done;
      })
    );
    wrapper.vm.openPicker();
    await flushPromises();
    await findButton('🧑🏽‍💻').trigger('click');
    expect(findButton('🧑🏽‍💻 1')).toBeTruthy();
    expect(messageReactionsAPI.react).toHaveBeenCalledWith(36, 12, '🧑🏽‍💻');
    resolve({ data: { reactions: [{ ...own, emoji: '🧑🏽‍💻' }, participant] } });
    await flushPromises();
    expect(findButton('🧑🏽‍💻 1')).toBeTruthy();
  });

  it('restores the previous own reaction when the provider fails', async () => {
    messageReactionsAPI.react.mockRejectedValue(new Error('Provider failed'));
    wrapper.vm.openPicker();
    await flushPromises();
    await findButton('🧑🏽‍💻').trigger('click');
    await flushPromises();
    expect(findButton('👍 2')).toBeTruthy();
    expect(findButton('🧑🏽‍💻 1')).toBeUndefined();
    expect(useAlert).toHaveBeenCalledWith('MESSAGE_REACTIONS.ERROR');
  });

  it('removes the own reaction from the complete picker', async () => {
    messageReactionsAPI.react.mockResolvedValue({
      data: { reactions: [participant, { ...own, emoji: '' }] },
    });
    wrapper.vm.openPicker();
    await flushPromises();
    await findButton('Remove my reaction').trigger('click');
    await flushPromises();
    expect(messageReactionsAPI.react).toHaveBeenCalledWith(36, 12, '');
    expect(findButton('👍 1')).toBeTruthy();
  });

  it('does not offer removal of another operator reaction', async () => {
    await wrapper.setProps({ reactions: [{ ...own, user_id: 8 }] });
    wrapper.vm.openPicker();
    await flushPromises();
    expect(wrapper.text()).not.toContain('MESSAGE_REACTIONS.REMOVE');
  });
});
