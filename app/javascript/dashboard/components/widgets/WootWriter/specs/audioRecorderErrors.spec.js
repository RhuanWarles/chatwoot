import {
  createUnavailableError,
  recorderErrorKey,
} from '../utils/audioRecorderErrors';

const ERRORS = 'CONVERSATION.REPLYBOX.AUDIO_RECORDER.ERRORS';

describe('recorderErrorKey', () => {
  it.each([
    ['NotAllowedError', `${ERRORS}.PERMISSION_DENIED`],
    ['SecurityError', `${ERRORS}.PERMISSION_DENIED`],
    ['NotFoundError', `${ERRORS}.NO_MICROPHONE`],
    ['OverconstrainedError', `${ERRORS}.NO_MICROPHONE`],
    ['AudioRecordingUnavailable', `${ERRORS}.UNAVAILABLE`],
  ])('explains %s', (name, key) => {
    expect(recorderErrorKey({ name })).toBe(key);
  });

  it('explains a browser that cannot record', () => {
    expect(recorderErrorKey(createUnavailableError())).toBe(
      `${ERRORS}.UNAVAILABLE`
    );
  });

  it('keeps the conversion message for anything else', () => {
    const conversion = 'CONVERSATION.REPLYBOX.AUDIO_CONVERSION_FAILED';

    expect(recorderErrorKey(new Error('ffmpeg'))).toBe(conversion);
    expect(recorderErrorKey(undefined)).toBe(conversion);
  });
});
