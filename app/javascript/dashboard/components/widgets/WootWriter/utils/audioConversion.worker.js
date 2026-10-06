import { bufferToWav, encodeToMP3 } from './audioEncoding';
import { remuxWebmToOgg } from './webmOpusToOgg';

globalThis.onmessage = async ({ data }) => {
  try {
    const { inputBlob, outputFormat, bitrate, channels, sampleRate } = data;
    let blob;
    if (inputBlob) {
      blob = await remuxWebmToOgg(inputBlob);
    } else if (outputFormat === 'audio/wav') {
      blob = await bufferToWav(
        {
          length: channels[0].length,
          getChannelData: index => channels[index],
        },
        channels.length,
        sampleRate
      );
    } else if (outputFormat === 'audio/mp3' || outputFormat === 'audio/ogg') {
      const samples = new Int16Array(channels[0].length);
      for (let index = 0; index < samples.length; index += 1) {
        const value =
          channels.reduce((sum, channel) => sum + channel[index], 0) /
          channels.length;
        const sample = Math.max(-1, Math.min(1, value));
        samples[index] = sample < 0 ? sample * 0x8000 : sample * 0x7fff;
      }
      blob = encodeToMP3(1, sampleRate, samples, bitrate);
    } else {
      throw new Error('Unsupported output format');
    }
    if (!blob.size) throw new Error('Empty converted recording');
    globalThis.postMessage({ blob });
  } catch (error) {
    globalThis.postMessage({ error: error.message });
  }
};
