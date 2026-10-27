<script>
import {
  formatMessageDateTime,
  formatMessageTime,
  messageIsoTime,
} from 'widget/helpers/messageTime';

export default {
  name: 'MessageTimestamp',
  props: {
    time: {
      type: [Number, String],
      default: null,
    },
  },
  computed: {
    locale() {
      return this.$i18n?.locale || 'pt-BR';
    },
    readableTime() {
      return formatMessageTime(this.time, this.locale);
    },
    fullTime() {
      return formatMessageDateTime(this.time, this.locale);
    },
    isoTime() {
      return messageIsoTime(this.time);
    },
  },
};
</script>

<template>
  <span class="contents">
    <time
      v-if="readableTime"
      :datetime="isoTime"
      :title="fullTime"
      class="pointer-events-none absolute end-2 bottom-1 select-none whitespace-nowrap text-[0.625rem] leading-none"
    >
      {{ readableTime }}
    </time>
  </span>
</template>
