import lamejs from '@breezystack/lamejs';

const writeString = (view, offset, string) => {
  // eslint-disable-next-line no-plusplus
  for (let i = 0; i < string.length; i++) {
    view.setUint8(offset + i, string.charCodeAt(i));
  }
};

export const bufferToWav = async (buffer, numChannels, sampleRate) => {
  const length = buffer.length * numChannels * 2;
  const wav = new ArrayBuffer(44 + length);
  const view = new DataView(wav);

  // WAV Header
  writeString(view, 0, 'RIFF');
  view.setUint32(4, 36 + length, true);
  writeString(view, 8, 'WAVE');
  writeString(view, 12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * numChannels * 2, true);
  view.setUint16(32, numChannels * 2, true);
  view.setUint16(34, 16, true);
  writeString(view, 36, 'data');
  view.setUint32(40, length, true);

  // WAV Data
  const offset = 44;
  // eslint-disable-next-line no-plusplus
  for (let i = 0; i < buffer.length; i++) {
    // eslint-disable-next-line no-plusplus
    for (let channel = 0; channel < numChannels; channel++) {
      const sample = Math.max(
        -1,
        Math.min(1, buffer.getChannelData(channel)[i])
      );
      view.setInt16(
        offset + (i * numChannels + channel) * 2,
        sample * 0x7fff,
        true
      );
    }
  }

  return new Blob([wav], { type: 'audio/wav' });
};

export const encodeToMP3 = (channels, sampleRate, samples, bitrate = 128) => {
  const outputBuffer = [];
  const encoder = new lamejs.Mp3Encoder(channels, sampleRate, bitrate);
  const maxSamplesPerFrame = 1152;

  for (let offset = 0; offset < samples.length; offset += maxSamplesPerFrame) {
    const sliceEnd = Math.min(offset + maxSamplesPerFrame, samples.length);
    const sampleSlice = samples.subarray(offset, sliceEnd);
    const mp3Buffer = encoder.encodeBuffer(sampleSlice);

    if (mp3Buffer.length > 0) {
      outputBuffer.push(new Int8Array(mp3Buffer));
    }
  }

  const remainingData = encoder.flush();
  if (remainingData.length > 0) {
    outputBuffer.push(new Int8Array(remainingData));
  }

  return new Blob(outputBuffer, { type: 'audio/mp3' });
};
