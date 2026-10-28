export const AUDIO_RECORDING_UNAVAILABLE = 'AudioRecordingUnavailable';

// The browser reports a blocked or missing microphone with these names. Anything else keeps the generic message.
const ERROR_KEYS = {
  NotAllowedError: 'PERMISSION_DENIED',
  SecurityError: 'PERMISSION_DENIED',
  NotFoundError: 'NO_MICROPHONE',
  OverconstrainedError: 'NO_MICROPHONE',
  [AUDIO_RECORDING_UNAVAILABLE]: 'UNAVAILABLE',
};

export const recorderErrorKey = error => {
  const key = ERROR_KEYS[error?.name];
  return key
    ? `CONVERSATION.REPLYBOX.AUDIO_RECORDER.ERRORS.${key}`
    : 'CONVERSATION.REPLYBOX.AUDIO_CONVERSION_FAILED';
};

export const createUnavailableError = () =>
  Object.assign(new Error('Audio recording is unavailable'), {
    name: AUDIO_RECORDING_UNAVAILABLE,
  });
