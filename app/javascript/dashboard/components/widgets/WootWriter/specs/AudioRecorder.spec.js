import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';

import messages from 'dashboard/i18n/locale/pt_BR/conversation.json';
import AudioRecorder from '../AudioRecorder.vue';

const mocks = vi.hoisted(() => ({
  surfer: null,
  record: null,
  convert: vi.fn(),
  startResult: () => Promise.resolve(),
}));

// Both fakes keep the handlers the component registers, so a spec can fire the events the real player and recorder emit.
const withEvents = target => {
  const handlers = {};
  return {
    ...target,
    on: (event, callback) => {
      handlers[event] = [...(handlers[event] || []), callback];
    },
    emit: async (event, ...args) => {
      await Promise.all(
        (handlers[event] || []).map(callback => callback(...args))
      );
    },
  };
};

vi.mock('wavesurfer.js', () => ({
  default: {
    create: options => {
      mocks.surfer = withEvents({
        plugins: options.plugins,
        load: vi.fn().mockResolvedValue(),
        playPause: vi.fn().mockResolvedValue(),
        destroy: vi.fn(),
      });
      return mocks.surfer;
    },
  },
}));

vi.mock('wavesurfer.js/dist/plugins/record.js', () => ({
  default: {
    create: () => {
      mocks.record = withEvents({
        startRecording: vi.fn(() => mocks.startResult()),
        stopRecording: vi.fn(),
        pauseRecording: vi.fn(),
        resumeRecording: vi.fn(),
        stopMic: vi.fn(),
        destroy: vi.fn(),
      });
      return mocks.record;
    },
  },
}));

vi.mock('../utils/audioConversionUtils', () => ({
  convertAudio: (...args) => mocks.convert(...args),
}));

const T = messages.CONVERSATION.REPLYBOX.AUDIO_RECORDER;

const mountRecorder = () =>
  mount(AudioRecorder, {
    props: { audioRecordFormat: 'audio/ogg' },
    global: {
      // the global stub only renders the slot, and the labels are props
      stubs: { NextButton: false },
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
    },
  });

const find = (wrapper, name) => wrapper.find(`[data-test="${name}"]`);
const phase = wrapper =>
  wrapper.find('[data-test="audio-recorder"]').attributes('data-phase');

const startRecording = async () => {
  const wrapper = mountRecorder();
  await flushPromises();
  return wrapper;
};

// Stops the recording the way the browser does: the plugin announces the recorded blob.
const finishRecording = async wrapper => {
  await find(wrapper, 'recorder-stop').trigger('click');
  await mocks.record.emit(
    'record-end',
    new Blob(['raw'], { type: 'audio/webm' })
  );
  await flushPromises();
};

beforeEach(() => {
  vi.clearAllMocks();
  window.MediaRecorder = class {
    static isTypeSupported() {
      return true;
    }
  };
  Object.defineProperty(navigator, 'mediaDevices', {
    value: { getUserMedia: vi.fn() },
    configurable: true,
  });
  URL.createObjectURL = vi.fn(() => 'blob:recording');
  URL.revokeObjectURL = vi.fn();
  mocks.convert.mockResolvedValue(new Blob(['ogg'], { type: 'audio/ogg' }));
  mocks.startResult = () => Promise.resolve();
});

afterEach(() => {
  delete window.MediaRecorder;
});

describe('AudioRecorder', () => {
  it('waits for the microphone and then shows that it is recording', async () => {
    let allowMicrophone;
    mocks.startResult = () =>
      new Promise(resolve => {
        allowMicrophone = resolve;
      });
    const wrapper = mountRecorder();

    expect(phase(wrapper)).toBe('starting');
    expect(find(wrapper, 'recorder-hint').text()).toBe(T.HINT_STARTING);
    expect(find(wrapper, 'recorder-live-dot').exists()).toBe(false);

    allowMicrophone();
    await flushPromises();
  });

  it('shows a live dot, a hint and the stop and pause buttons while recording', async () => {
    const wrapper = await startRecording();

    expect(mocks.record.startRecording).toHaveBeenCalled();
    expect(phase(wrapper)).toBe('recording');
    expect(find(wrapper, 'recorder-live-dot').exists()).toBe(true);
    expect(find(wrapper, 'recorder-hint').text()).toBe(T.HINT_RECORDING);
    expect(find(wrapper, 'recorder-stop').text()).toBe(T.STOP);
    expect(find(wrapper, 'recorder-pause').text()).toBe(T.PAUSE);
  });

  it('shows the time that was recorded', async () => {
    const wrapper = await startRecording();

    await mocks.record.emit('record-progress', 65000);

    expect(find(wrapper, 'recorder-time').text()).toBe('01:05');
    expect(wrapper.emitted('recorderProgressChanged')[0]).toEqual(['01:05']);
  });

  it('pauses and resumes the recording', async () => {
    const wrapper = await startRecording();

    await find(wrapper, 'recorder-pause').trigger('click');

    expect(mocks.record.pauseRecording).toHaveBeenCalled();
    expect(phase(wrapper)).toBe('paused');
    expect(find(wrapper, 'recorder-live-dot').exists()).toBe(false);
    expect(find(wrapper, 'recorder-pause').text()).toBe(T.RESUME);
    expect(find(wrapper, 'recorder-hint').text()).toBe(T.HINT_PAUSED);

    await find(wrapper, 'recorder-pause').trigger('click');

    expect(mocks.record.resumeRecording).toHaveBeenCalled();
    expect(phase(wrapper)).toBe('recording');
  });

  it('can be stopped while it is paused', async () => {
    const wrapper = await startRecording();
    await find(wrapper, 'recorder-pause').trigger('click');

    await find(wrapper, 'recorder-stop').trigger('click');

    expect(mocks.record.stopRecording).toHaveBeenCalled();
    expect(phase(wrapper)).toBe('processing');
  });

  it('shows that the audio is being prepared after stopping', async () => {
    const wrapper = await startRecording();

    await find(wrapper, 'recorder-stop').trigger('click');

    expect(mocks.record.stopRecording).toHaveBeenCalled();
    expect(phase(wrapper)).toBe('processing');
    expect(find(wrapper, 'recorder-processing').exists()).toBe(true);
    expect(find(wrapper, 'recorder-stop').exists()).toBe(false);
  });

  it('hands the converted file over and becomes ready to play', async () => {
    const wrapper = await startRecording();

    await finishRecording(wrapper);

    expect(mocks.surfer.load).toHaveBeenCalledWith('blob:recording');
    const [{ name, type, file }] = wrapper.emitted('finishRecord')[0];
    expect(name).toMatch(/\.ogg$/);
    expect(type).toBe('audio/ogg');
    expect(file).toBeInstanceOf(File);
    expect(phase(wrapper)).toBe('ready');
    expect(find(wrapper, 'recorder-hint').text()).toBe(T.HINT_READY);
    expect(find(wrapper, 'recorder-play').text()).toBe(T.PLAY);
    expect(find(wrapper, 'recorder-rerecord').text()).toBe(T.RERECORD);
  });

  it('plays the recording and shows the position over the total', async () => {
    const wrapper = await startRecording();
    await finishRecording(wrapper);
    mocks.surfer.emit('ready', 10);

    await find(wrapper, 'recorder-play').trigger('click');
    mocks.surfer.emit('play');
    mocks.surfer.emit('timeupdate', 3);
    await flushPromises();

    expect(mocks.surfer.playPause).toHaveBeenCalled();
    expect(find(wrapper, 'recorder-play').text()).toBe(T.PAUSE_PLAYBACK);
    expect(find(wrapper, 'recorder-time').text()).toBe('00:03 / 00:10');

    mocks.surfer.emit('finish');
    await flushPromises();

    expect(find(wrapper, 'recorder-play').text()).toBe(T.PLAY);
  });

  it('asks the parent to discard the recording', async () => {
    const wrapper = await startRecording();

    await find(wrapper, 'recorder-discard').trigger('click');

    expect(wrapper.emitted('discard')).toHaveLength(1);
  });

  it('asks the parent to record again once the audio is ready', async () => {
    const wrapper = await startRecording();
    await finishRecording(wrapper);

    await find(wrapper, 'recorder-rerecord').trigger('click');

    expect(wrapper.emitted('rerecord')).toHaveLength(1);
  });

  it('reports a blocked microphone and releases it', async () => {
    const denied = Object.assign(new Error('denied'), {
      name: 'NotAllowedError',
    });
    mocks.startResult = () => Promise.reject(denied);
    const wrapper = mountRecorder();
    await flushPromises();

    expect(wrapper.emitted('recordError')[0][0].error).toBe(denied);
    expect(mocks.record.stopMic).toHaveBeenCalled();
  });

  it('reports a recording that could not be converted', async () => {
    const failure = new Error('ffmpeg');
    mocks.convert.mockRejectedValue(failure);
    const wrapper = await startRecording();

    await finishRecording(wrapper);

    expect(wrapper.emitted('recordError')[0][0].error).toBe(failure);
    expect(wrapper.emitted('finishRecord')).toBeUndefined();
  });

  it('reports a browser that cannot record', async () => {
    delete window.MediaRecorder;
    const wrapper = mountRecorder();

    expect(wrapper.emitted('recordError')[0][0].error.name).toBe(
      'AudioRecordingUnavailable'
    );
  });

  it('cleans up the player and the audio url when it goes away', async () => {
    const wrapper = await startRecording();
    await finishRecording(wrapper);

    wrapper.unmount();

    expect(mocks.surfer.destroy).toHaveBeenCalled();
    expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:recording');
  });
});
