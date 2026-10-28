<script setup>
import getUuid from 'widget/helpers/uuid';
import { computed, ref, shallowRef, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import WaveSurfer from 'wavesurfer.js';
import RecordPlugin from 'wavesurfer.js/dist/plugins/record.js';
import { format, intervalToDuration } from 'date-fns';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { convertAudio } from './utils/audioConversionUtils';
import { createUnavailableError } from './utils/audioRecorderErrors';
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
  'discard',
  'rerecord',
]);

const { t } = useI18n();

const waveformContainer = ref(null);
const wavesurfer = shallowRef(null);
const record = shallowRef(null);
const { run: convertRecording } = useAbortableRequest();
let disposed = false;
const isRecording = ref(false);
const isPaused = ref(false);
const isProcessing = ref(false);
const hasRecording = ref(false);
const isPlaying = ref(false);
const recordedAudioUrl = ref(null);
const elapsedTime = ref(0);
const playbackTime = ref(0);
const totalTime = ref(0);

// starting: waiting for the microphone, recording, paused, processing: converting the audio, ready: can be played and sent
const phase = computed(() => {
  if (isProcessing.value) return 'processing';
  if (hasRecording.value) return 'ready';
  if (isPaused.value) return 'paused';
  if (isRecording.value) return 'recording';
  return 'starting';
});

const formatTimeProgress = time => {
  const duration = intervalToDuration({ start: 0, end: time });
  return format(
    new Date(0, 0, 0, 0, duration.minutes, duration.seconds),
    'mm:ss'
  );
};

const timeText = computed(() =>
  phase.value === 'ready'
    ? `${formatTimeProgress(playbackTime.value)} / ${formatTimeProgress(totalTime.value)}`
    : formatTimeProgress(elapsedTime.value)
);

const statusLabel = computed(
  () =>
    ({
      starting: t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.STARTING'),
      recording: t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.RECORDING'),
      paused: t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.PAUSED'),
      processing: t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.PROCESSING'),
      ready: '',
    })[phase.value]
);

const hint = computed(
  () =>
    ({
      starting: t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.HINT_STARTING'),
      recording: t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.HINT_RECORDING'),
      paused: t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.HINT_PAUSED'),
      processing: t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.HINT_PROCESSING'),
      ready: t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.HINT_READY'),
    })[phase.value]
);

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
    height: 48,
    barWidth: 2,
    barGap: 1,
    barRadius: 2,
    plugins: [
      RecordPlugin.create(getRecordPluginOptions(props.audioRecordFormat)),
    ],
  });

  wavesurfer.value.on('pause', () => {
    isPlaying.value = false;
    emit('pause');
  });
  wavesurfer.value.on('play', () => {
    isPlaying.value = true;
    emit('play');
  });
  wavesurfer.value.on('finish', () => {
    isPlaying.value = false;
  });
  wavesurfer.value.on('timeupdate', seconds => {
    playbackTime.value = seconds * 1000;
  });
  wavesurfer.value.on('ready', seconds => {
    totalTime.value = seconds * 1000;
  });

  record.value = wavesurfer.value.plugins[0];

  record.value.on('record-pause', () => {
    isPaused.value = true;
  });
  record.value.on('record-resume', () => {
    isPaused.value = false;
  });

  record.value.on('record-end', async blob => {
    if (disposed) return;
    record.value.stopMic();
    isRecording.value = false;
    isPaused.value = false;
    isProcessing.value = true;
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
      isProcessing.value = false;
    } catch (error) {
      if (disposed) return;
      isProcessing.value = false;
      hasRecording.value = false;
      emit('recordError', { error });
    }
  });

  record.value.on('record-progress', time => {
    elapsedTime.value = time;
    emit('recorderProgressChanged', formatTimeProgress(time));
  });
};

const stopRecording = () => {
  if (isRecording.value || isPaused.value) {
    record.value.stopRecording();
    isRecording.value = false;
    isPaused.value = false;
    isProcessing.value = true;
  }
};

const togglePauseRecording = () => {
  if (isPaused.value) {
    record.value.resumeRecording();
    isPaused.value = false;
  } else if (isRecording.value) {
    record.value.pauseRecording();
    isPaused.value = true;
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
    emit('recordError', { error: createUnavailableError() });
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
  <div
    class="flex flex-col w-full gap-1 px-3 py-2"
    :data-phase="phase"
    data-test="audio-recorder"
  >
    <div class="flex items-center w-full gap-3">
      <NextButton
        v-tooltip.top="t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.DISCARD')"
        :aria-label="t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.DISCARD')"
        icon="i-lucide-trash-2"
        ruby
        faded
        sm
        data-test="recorder-discard"
        @click="emit('discard')"
      />
      <div class="flex items-center gap-1.5 shrink-0">
        <span
          v-if="phase === 'recording'"
          class="rounded-full size-2.5 bg-n-ruby-9 animate-pulse"
          aria-hidden="true"
          data-test="recorder-live-dot"
        />
        <span
          v-else-if="phase === 'paused'"
          class="i-lucide-pause size-3.5 text-n-amber-11"
          aria-hidden="true"
        />
        <span class="sr-only" role="status">{{ statusLabel }}</span>
        <span
          class="text-sm font-medium tabular-nums text-n-slate-12"
          data-test="recorder-time"
        >
          {{ timeText }}
        </span>
      </div>
      <div
        ref="waveformContainer"
        class="flex-1 min-w-0"
        :class="{
          'opacity-40': phase === 'starting' || phase === 'processing',
        }"
      />
      <div class="flex items-center gap-1 shrink-0">
        <template v-if="phase === 'recording' || phase === 'paused'">
          <NextButton
            :icon="phase === 'paused' ? 'i-lucide-mic' : 'i-lucide-pause'"
            :label="
              phase === 'paused'
                ? t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.RESUME')
                : t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.PAUSE')
            "
            slate
            faded
            sm
            data-test="recorder-pause"
            @click="togglePauseRecording"
          />
          <NextButton
            icon="i-lucide-square"
            :label="t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.STOP')"
            sm
            data-test="recorder-stop"
            @click="stopRecording"
          />
        </template>
        <NextButton
          v-else-if="phase === 'processing'"
          slate
          faded
          sm
          is-loading
          disabled
          data-test="recorder-processing"
        />
        <template v-else-if="phase === 'ready'">
          <NextButton
            :icon="isPlaying ? 'i-lucide-pause' : 'i-lucide-play'"
            :label="
              isPlaying
                ? t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.PAUSE_PLAYBACK')
                : t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.PLAY')
            "
            slate
            faded
            sm
            data-test="recorder-play"
            @click="playPause"
          />
          <NextButton
            icon="i-lucide-rotate-ccw"
            :label="t('CONVERSATION.REPLYBOX.AUDIO_RECORDER.RERECORD')"
            slate
            ghost
            sm
            data-test="recorder-rerecord"
            @click="emit('rerecord')"
          />
        </template>
      </div>
    </div>
    <p class="m-0 text-xs text-n-slate-11" data-test="recorder-hint">
      {{ hint }}
    </p>
  </div>
</template>
