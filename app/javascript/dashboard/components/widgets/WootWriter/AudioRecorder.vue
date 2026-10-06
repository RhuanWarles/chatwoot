<script setup>
import getUuid from 'widget/helpers/uuid';
import { ref, shallowRef, onMounted, onUnmounted } from 'vue';
import WaveSurfer from 'wavesurfer.js';
import RecordPlugin from 'wavesurfer.js/dist/plugins/record.js';
import { format, intervalToDuration } from 'date-fns';
import { convertAudio } from './utils/audioConversionUtils';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';

const props = defineProps({
  audioRecordFormat: {
    type: String,
    required: true,
  },
});

const emit = defineEmits([
  'recorderProgressChanged',
  'finishRecord',
  'pause',
  'play',
  'recordError',
  'processing',
]);

const waveformContainer = ref(null);
const wavesurfer = shallowRef(null);
const record = shallowRef(null);
const { run: convertRecording } = useAbortableRequest();
let disposed = false;
const isRecording = ref(false);
const hasRecording = ref(false);
const recordedAudioUrl = ref(null);

const formatTimeProgress = time => {
  const duration = intervalToDuration({ start: 0, end: time });
  return format(
    new Date(0, 0, 0, 0, duration.minutes, duration.seconds),
    'mm:ss'
  );
};

const AUDIO_EXTENSION_MAP = {
  'audio/ogg': 'ogg',
  'audio/mp3': 'mp3',
  'audio/mpeg': 'mp3',
  'audio/wav': 'wav',
  'audio/webm': 'webm',
};

const getRecordPluginOptions = audioFormat => {
  const options = {
    scrollingWaveform: true,
    renderRecordedAudio: false,
  };
  if (
    audioFormat === 'audio/ogg' &&
    MediaRecorder.isTypeSupported('audio/ogg;codecs=opus')
  ) {
    options.mimeType = 'audio/ogg;codecs=opus';
  }
  return options;
};

const initWaveSurfer = () => {
  wavesurfer.value = WaveSurfer.create({
    container: waveformContainer.value,
    waveColor: '#1F93FF',
    progressColor: '#6E6F73',
    height: 100,
    barWidth: 2,
    barGap: 1,
    barRadius: 2,
    plugins: [
      RecordPlugin.create(getRecordPluginOptions(props.audioRecordFormat)),
    ],
  });

  wavesurfer.value.on('pause', () => emit('pause'));
  wavesurfer.value.on('play', () => emit('play'));

  record.value = wavesurfer.value.plugins[0];

  record.value.on('record-end', async blob => {
    if (disposed) return;
    record.value.stopMic();
    emit('processing');
    try {
      const audioBlob = await convertRecording(signal =>
        convertAudio(blob, props.audioRecordFormat, 128, { signal })
      );
      if (disposed || !audioBlob) return;
      // Use the converted blob's actual type, which may differ from the
      // requested format when the browser can't produce it (e.g. Safari falls
      // back to MP3 instead of OGG). This keeps the filename, content type, and
      // voice-note flag consistent with the real bytes.
      const audioType = audioBlob.type;
      const ext = AUDIO_EXTENSION_MAP[audioType.split(';')[0].trim()];
      if (!ext) throw new Error('Unsupported audio recording format');
      const fileName = `${getUuid()}.${ext}`;
      const file = new File([audioBlob], fileName, {
        type: audioType,
      });
      if (recordedAudioUrl.value) URL.revokeObjectURL(recordedAudioUrl.value);
      recordedAudioUrl.value = URL.createObjectURL(audioBlob);
      await wavesurfer.value.load(recordedAudioUrl.value);
      if (disposed) return;
      emit('finishRecord', {
        name: file.name,
        type: file.type,
        size: file.size,
        file,
      });
      hasRecording.value = true;
      isRecording.value = false;
    } catch (error) {
      if (disposed) return;
      isRecording.value = false;
      hasRecording.value = false;
      emit('recordError', { error });
    }
  });

  record.value.on('record-progress', time => {
    emit('recorderProgressChanged', formatTimeProgress(time));
  });
};

const stopRecording = () => {
  if (isRecording.value) {
    record.value.stopRecording();
    isRecording.value = false;
  }
};

const startRecording = async () => {
  try {
    await record.value.startRecording();
    if (disposed) {
      record.value.destroy();
      return;
    }
    isRecording.value = true;
  } catch (error) {
    if (disposed) return;
    record.value.stopMic();
    emit('recordError', { error });
  }
};

const playPause = () => {
  if (hasRecording.value) {
    wavesurfer.value.playPause().catch(error => emit('recordError', { error }));
  }
};

onMounted(() => {
  if (!window.MediaRecorder || !navigator.mediaDevices?.getUserMedia) {
    emit('recordError', { error: new Error('Audio recording is unavailable') });
    return;
  }
  initWaveSurfer();
  startRecording();
});

onUnmounted(() => {
  disposed = true;
  if (recordedAudioUrl.value) {
    URL.revokeObjectURL(recordedAudioUrl.value);
    recordedAudioUrl.value = null;
  }
  if (wavesurfer.value) {
    wavesurfer.value.destroy();
  }
});

defineExpose({ playPause, stopRecording, record });
</script>

<template>
  <div ref="waveformContainer" class="w-full p-1" />
</template>
