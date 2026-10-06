export { encodeToMP3 } from './audioEncoding';

export const convertAudio = async (
  inputBlob,
  outputFormat,
  bitrate = 128,
  { signal } = {}
) => {
  if (!inputBlob.size) throw new Error('Empty audio recording');
  const inputType = inputBlob.type.split(';')[0].trim();
  if (outputFormat === 'audio/ogg' && inputType === 'audio/ogg')
    return inputBlob;
  let payload = { inputBlob, outputFormat, bitrate };
  const transfer = [];
  if (!(outputFormat === 'audio/ogg' && inputType.includes('webm'))) {
    const context = new (window.AudioContext || window.webkitAudioContext)();
    try {
      const decoded = await context.decodeAudioData(
        await inputBlob.arrayBuffer()
      );
      const channels = Array.from(
        { length: decoded.numberOfChannels },
        (_, index) => decoded.getChannelData(index).slice()
      );
      payload = {
        channels,
        sampleRate: decoded.sampleRate,
        outputFormat,
        bitrate,
      };
      transfer.push(...channels.map(channel => channel.buffer));
    } finally {
      await context.close();
    }
  }
  if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError');
  return new Promise((resolve, reject) => {
    const worker = new Worker(
      new URL('./audioConversion.worker.js', import.meta.url),
      {
        type: 'module',
      }
    );
    const cancel = () => {
      worker.terminate();
      reject(new DOMException('Cancelled', 'AbortError'));
    };
    const cleanup = () => {
      worker.terminate();
      signal?.removeEventListener('abort', cancel);
    };
    signal?.addEventListener('abort', cancel, { once: true });
    worker.onmessage = ({ data }) => {
      cleanup();
      if (data.error) reject(new Error(data.error));
      else resolve(data.blob);
    };
    worker.onerror = error => {
      cleanup();
      reject(new Error(error.message));
    };
    worker.postMessage(payload, transfer);
  });
};

export const convertToWav = blob => convertAudio(blob, 'audio/wav');
export const convertToMp3 = (blob, bitrate = 128) =>
  convertAudio(blob, 'audio/mp3', bitrate);
