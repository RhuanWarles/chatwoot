import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { ref } from 'vue';

import searchAPI from 'dashboard/api/search';
import messages from 'dashboard/i18n/locale/pt_BR/chatlist.json';
import ChatListSearch from '../ChatListSearch.vue';

vi.mock('dashboard/api/search', () => ({
  default: { conversations: vi.fn() },
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: ref(7) }),
}));

const RouterLink = {
  props: ['to'],
  emits: ['click'],
  template: '<a :href="to" @click.prevent="$emit(\'click\')"><slot /></a>',
};

const conversation = (id, name, phone) => ({
  id,
  contact: { name, phone_number: phone },
  inbox: { name: 'WhatsApp' },
});

const mountSearch = () =>
  mount(ChatListSearch, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: { RouterLink },
    },
  });

const type = async (wrapper, text) => {
  await wrapper.find('[data-test="list-search"]').setValue(text);
  vi.advanceTimersByTime(300);
  await flushPromises();
};

beforeEach(() => {
  vi.useFakeTimers();
  vi.clearAllMocks();
  searchAPI.conversations.mockResolvedValue({
    data: {
      payload: {
        conversations: [conversation(12, 'Jorge Silva', '+5562991212010')],
      },
    },
  });
});
afterEach(() => vi.useRealTimers());

describe('ChatListSearch', () => {
  it('waits for the typing to pause before searching', async () => {
    const wrapper = mountSearch();

    await wrapper.find('[data-test="list-search"]').setValue('Jo');
    await wrapper.find('[data-test="list-search"]').setValue('Jorge');
    expect(searchAPI.conversations).not.toHaveBeenCalled();

    vi.advanceTimersByTime(300);
    await flushPromises();

    expect(searchAPI.conversations).toHaveBeenCalledTimes(1);
    expect(searchAPI.conversations).toHaveBeenCalledWith({ q: 'Jorge' });
  });

  it('does not search for a single character', async () => {
    const wrapper = mountSearch();

    await type(wrapper, 'J');

    expect(searchAPI.conversations).not.toHaveBeenCalled();
    expect(wrapper.find('[data-test="list-search-panel"]').exists()).toBe(
      false
    );
  });

  it('lists the conversations with the contact name, phone and inbox', async () => {
    const wrapper = mountSearch();

    await type(wrapper, 'Jorge');

    const [result] = wrapper.findAll('[data-test="list-search-result"]');
    expect(result.text()).toContain('Jorge Silva');
    expect(result.text()).toContain('+5562991212010');
    expect(result.text()).toContain('#12');
    expect(result.text()).toContain('WhatsApp');
    expect(result.attributes('href')).toBe('/app/accounts/7/conversations/12');
  });

  it('finds a phone typed the way people write it', async () => {
    const wrapper = mountSearch();

    await type(wrapper, '(62) 99121-2010');

    expect(searchAPI.conversations).toHaveBeenCalledWith({ q: '62991212010' });
  });

  it('says so when nothing is found', async () => {
    searchAPI.conversations.mockResolvedValue({
      data: { payload: { conversations: [] } },
    });
    const wrapper = mountSearch();

    await type(wrapper, 'Zzz');

    expect(wrapper.find('[data-test="list-search-panel"]').text()).toContain(
      messages.CHAT_LIST.SEARCH.EMPTY
    );
  });

  it('warns when the search fails', async () => {
    searchAPI.conversations.mockRejectedValue(new Error('500'));
    const wrapper = mountSearch();

    await type(wrapper, 'Jorge');

    expect(wrapper.find('[role="alert"]').text()).toContain(
      messages.CHAT_LIST.SEARCH.ERROR
    );
  });

  it('shows the answer of the last search when an older one finishes later', async () => {
    let finishFirst;
    searchAPI.conversations
      .mockReturnValueOnce(
        new Promise(resolve => {
          finishFirst = resolve;
        })
      )
      .mockResolvedValueOnce({
        data: {
          payload: { conversations: [conversation(99, 'Maria Souza', null)] },
        },
      });
    const wrapper = mountSearch();

    await type(wrapper, 'Jo');
    await type(wrapper, 'Maria');
    finishFirst({
      data: {
        payload: { conversations: [conversation(1, 'Jorge Velho', null)] },
      },
    });
    await flushPromises();

    const text = wrapper.find('[data-test="list-search-panel"]').text();
    expect(text).toContain('Maria Souza');
    expect(text).not.toContain('Jorge Velho');
  });

  it('closes the results when a conversation is chosen', async () => {
    const wrapper = mountSearch();
    await type(wrapper, 'Jorge');

    await wrapper.find('[data-test="list-search-result"]').trigger('click');

    expect(wrapper.find('[data-test="list-search-panel"]').exists()).toBe(
      false
    );
  });

  it('clears the field and the results', async () => {
    const wrapper = mountSearch();
    await type(wrapper, 'Jorge');

    await wrapper.find('[data-test="list-search-clear"]').trigger('click');

    expect(wrapper.find('[data-test="list-search"]').element.value).toBe('');
    expect(wrapper.find('[data-test="list-search-panel"]').exists()).toBe(
      false
    );
  });
});
