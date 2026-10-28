import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';

import messages from 'dashboard/i18n/locale/pt_BR/conversation.json';
import AudioChip from '../Audio.vue';

const mocks = vi.hoisted(() => ({ transcribe: vi.fn(), alert: vi.fn() }));
vi.mock('dashboard/api/inbox/message', () => ({
  default: { transcribeAudio: mocks.transcribe },
}));
vi.mock('dashboard/composables', () => ({ useAlert: mocks.alert }));

const T = messages.CONVERSATION.TRANSCRIBE;

const audio = overrides => ({
  id: 7,
  messageId: 33,
  fileType: 'audio',
  dataUrl: 'https://example.com/audio.mp3',
  transcribedText: '',
  ...overrides,
});

const mountChip = props =>
  mount(AudioChip, {
    props: { attachment: audio(), conversationId: 12, ...props },
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

const button = wrapper => wrapper.find('[data-test="transcribe-audio"]');

beforeEach(() => {
  vi.clearAllMocks();
  mocks.transcribe.mockResolvedValue({ status: 202 });
});

afterEach(() => {
  vi.useRealTimers();
});

describe('Audio chip transcription button', () => {
  it('offers "Transcrever" for an audio without text', () => {
    const wrapper = mountChip();

    expect(button(wrapper).text()).toBe(T.BUTTON);
  });

  it('has no button when the caller does not allow transcribing', () => {
    const wrapper = mountChip({ conversationId: null });

    expect(button(wrapper).exists()).toBe(false);
  });

  it('has no button when the audio is already transcribed', () => {
    const wrapper = mountChip({
      attachment: audio({ transcribedText: 'Olá, tudo bem?' }),
    });

    expect(button(wrapper).exists()).toBe(false);
    expect(wrapper.text()).toContain('Olá, tudo bem?');
  });

  it('asks for the transcription of this audio and waits for the text', async () => {
    const wrapper = mountChip();

    await button(wrapper).trigger('click');
    await flushPromises();

    expect(mocks.transcribe).toHaveBeenCalledWith({
      conversationId: 12,
      messageId: 33,
      attachmentId: 7,
    });
    expect(button(wrapper).text()).toBe(T.LOADING);
    expect(button(wrapper).attributes('disabled')).toBeDefined();
  });

  it('does not ask twice while it is waiting', async () => {
    const wrapper = mountChip();

    await button(wrapper).trigger('click');
    await button(wrapper).trigger('click');
    await flushPromises();

    expect(mocks.transcribe).toHaveBeenCalledTimes(1);
  });

  it('shows the text when the message update brings it', async () => {
    const wrapper = mountChip();
    await button(wrapper).trigger('click');
    await flushPromises();

    await wrapper.setProps({
      attachment: audio({ transcribedText: 'Quero saber o preço' }),
    });

    expect(button(wrapper).exists()).toBe(false);
    expect(wrapper.text()).toContain('Quero saber o preço');
  });

  it('explains that the credits are over', async () => {
    mocks.transcribe.mockRejectedValue({
      response: { status: 402, data: { error: 'insufficient_balance' } },
    });
    const wrapper = mountChip();

    await button(wrapper).trigger('click');
    await flushPromises();

    expect(mocks.alert).toHaveBeenCalledWith(T.ERRORS.insufficient_balance);
    expect(button(wrapper).text()).toBe(T.BUTTON);
  });

  it('uses a generic message for an error it does not know', async () => {
    mocks.transcribe.mockRejectedValue({ response: { data: { error: 'x' } } });
    const wrapper = mountChip();

    await button(wrapper).trigger('click');
    await flushPromises();

    expect(mocks.alert).toHaveBeenCalledWith(T.ERRORS.GENERIC);
  });

  it('uses the generic message when the request has no response', async () => {
    mocks.transcribe.mockRejectedValue(new Error('Network Error'));
    const wrapper = mountChip();

    await button(wrapper).trigger('click');
    await flushPromises();

    expect(mocks.alert).toHaveBeenCalledWith(T.ERRORS.GENERIC);
  });

  it('gives up waiting after a while and lets the agent try again', async () => {
    vi.useFakeTimers();
    const wrapper = mountChip();

    await button(wrapper).trigger('click');
    await flushPromises();
    await vi.advanceTimersByTimeAsync(90000);

    expect(mocks.alert).toHaveBeenCalledWith(T.TIMEOUT);
    expect(button(wrapper).text()).toBe(T.BUTTON);
  });

  it('stops waiting when the server says the audio already has a text', async () => {
    mocks.transcribe.mockResolvedValue({ status: 200 });
    const wrapper = mountChip();

    await button(wrapper).trigger('click');
    await flushPromises();

    expect(button(wrapper).text()).toBe(T.BUTTON);
    expect(mocks.alert).not.toHaveBeenCalled();
  });
});
