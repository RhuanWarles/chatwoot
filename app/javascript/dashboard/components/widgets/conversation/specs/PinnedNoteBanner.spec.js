import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';

import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import messages from 'dashboard/i18n/locale/pt_BR/conversation.json';
import PinnedNoteBanner from '../PinnedNoteBanner.vue';

const mocks = vi.hoisted(() => ({ dispatch: vi.fn(), alert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: mocks.dispatch }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: mocks.alert }));

const note = overrides => ({
  message_id: 55,
  content: 'Cliente só atende depois das 18h',
  pinned_by: { id: 3, name: 'Brenda' },
  ...overrides,
});

const mountBanner = props =>
  mount(PinnedNoteBanner, {
    props: { conversationId: 12, note: note(), ...props },
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
    },
  });

const find = (wrapper, name) =>
  wrapper.find(`[data-test="pinned-note-${name}"]`);

beforeEach(() => {
  vi.clearAllMocks();
  mocks.dispatch.mockResolvedValue();
});

describe('PinnedNoteBanner', () => {
  it('shows the text of the note and who pinned it', () => {
    const wrapper = mountBanner();

    expect(find(wrapper, 'text').text()).toBe(
      'Cliente só atende depois das 18h'
    );
    expect(wrapper.text()).toContain('Fixada por Brenda');
  });

  it('does not offer "show more" for a short note', () => {
    const wrapper = mountBanner();

    expect(find(wrapper, 'toggle').exists()).toBe(false);
  });

  it('folds a long note and unfolds it on demand', async () => {
    const wrapper = mountBanner({ note: note({ content: 'a'.repeat(300) }) });

    expect(find(wrapper, 'text').classes()).toContain('line-clamp-2');
    expect(find(wrapper, 'toggle').text()).toBe(
      messages.CONVERSATION.PINNED_NOTE.SHOW_MORE
    );

    await find(wrapper, 'toggle').trigger('click');

    expect(find(wrapper, 'text').classes()).not.toContain('line-clamp-2');
    expect(find(wrapper, 'toggle').text()).toBe(
      messages.CONVERSATION.PINNED_NOTE.SHOW_LESS
    );
  });

  it('also folds a note that has several lines', () => {
    const wrapper = mountBanner({
      note: note({ content: 'linha 1\nlinha 2' }),
    });

    expect(find(wrapper, 'toggle').exists()).toBe(true);
  });

  it('scrolls the chat to the note', async () => {
    const emit = vi.spyOn(emitter, 'emit');
    const wrapper = mountBanner();

    await find(wrapper, 'go').trigger('click');

    expect(emit).toHaveBeenCalledWith(BUS_EVENTS.SCROLL_TO_MESSAGE, {
      messageId: 55,
    });
    emit.mockRestore();
  });

  it('unpins the note of this conversation', async () => {
    const wrapper = mountBanner();

    await find(wrapper, 'unpin').trigger('click');
    await flushPromises();

    expect(mocks.dispatch).toHaveBeenCalledWith('unpinNote', {
      conversationId: 12,
    });
  });

  it('warns when the note could not be unpinned', async () => {
    mocks.dispatch.mockRejectedValue(new Error('500'));
    const wrapper = mountBanner();

    await find(wrapper, 'unpin').trigger('click');
    await flushPromises();

    expect(mocks.alert).toHaveBeenCalledWith(
      messages.CONVERSATION.PINNED_NOTE.UNPIN_ERROR
    );
  });
});
