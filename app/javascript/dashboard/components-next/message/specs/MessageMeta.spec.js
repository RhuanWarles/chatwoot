import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import MessageMeta from '../MessageMeta.vue';

vi.mock('shared/helpers/timeHelper', () => ({
  messageTimestamp: () => 'Oct 23, 12:54 PM',
}));
vi.mock('shared/composables/useExactTimestamp', () => ({
  useExactTimestamp: () => () => 'Oct 23, 12:54 PM',
}));
vi.mock('dashboard/composables/useInbox', () => ({
  useInbox: () => ({
    isAFacebookInbox: ref(false),
    isALineChannel: ref(false),
    isAPIInbox: ref(true),
    isASmsInbox: ref(false),
    isATelegramChannel: ref(false),
    isATwilioChannel: ref(false),
    isAWebWidgetInbox: ref(false),
    isAWhatsAppChannel: ref(false),
    isAnEmailChannel: ref(false),
    isAnInstagramChannel: ref(false),
    isATiktokChannel: ref(false),
  }),
}));
vi.mock('../provider.js', () => ({
  useMessageContext: () => ({
    status: ref('sent'),
    isPrivate: ref(false),
    createdAt: ref(1729688040),
    sourceId: ref('WAID:wamid-42'),
    messageType: ref(1),
    contentAttributes: ref({ whatsapp_message_edited: true }),
  }),
}));

describe('MessageMeta', () => {
  it('renders the edited indicator separately from the timestamp', () => {
    const wrapper = mount(MessageMeta, {
      global: {
        directives: { tooltip: {} },
        mocks: {
          $t: key => (key === 'CONVERSATION.MESSAGE_EDITED' ? 'Editada' : key),
        },
        stubs: {
          Icon: true,
          MessageStatus: true,
        },
      },
    });

    expect(wrapper.find('time').text()).toBe('Oct 23, 12:54 PM');
    const editedIndicator = wrapper.find(
      '[data-testid="message-edited-indicator"]'
    );

    expect(editedIndicator.text()).toContain('Editada');
    expect(editedIndicator.classes()).toContain("before:content-['·']");
    expect(wrapper.text()).toContain('Oct 23, 12:54 PM');
    expect(wrapper.text()).toContain('Editada');
  });
});
