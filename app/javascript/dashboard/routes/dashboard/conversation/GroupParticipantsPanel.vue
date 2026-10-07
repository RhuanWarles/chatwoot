<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import groupParticipantsAPI from 'dashboard/api/conversations/groupParticipantsAPI';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const participants = ref([]);
const loading = ref(false);
const failed = ref(false);

const formatPhone = phone => {
  if (!phone) return '';
  if (/^55\d{11}$/.test(phone)) {
    return `+55 ${phone.slice(2, 4)} ${phone.slice(4, 9)}-${phone.slice(9)}`;
  }
  return `+${phone}`;
};

const loadParticipants = async () => {
  loading.value = true;
  try {
    participants.value =
      (await groupParticipantsAPI(props.conversationId).get()).data
        .participants || [];
  } catch {
    failed.value = true;
  } finally {
    loading.value = false;
  }
};

onMounted(loadParticipants);
</script>

<template>
  <div class="flex flex-col gap-2 px-1 pb-1">
    <div v-if="loading" class="py-2 text-sm text-n-slate-11">
      {{ t('CONVERSATION.GROUP_PARTICIPANTS.LOADING') }}
    </div>
    <div v-else-if="failed" class="py-2 text-sm text-n-slate-11">
      {{ t('CONVERSATION.GROUP_PARTICIPANTS.ERROR') }}
    </div>
    <div
      v-else-if="!participants.length"
      class="py-2 text-sm text-n-slate-11"
    >
      {{ t('CONVERSATION.GROUP_PARTICIPANTS.EMPTY') }}
    </div>
    <div
      v-for="participant in participants"
      :key="participant.lid || participant.jid"
      class="flex items-center min-w-0 gap-2 py-1"
    >
      <Avatar
        :src="participant.avatar_url"
        :name="participant.display_name"
        :size="28"
        rounded-full
        class="flex-shrink-0"
      />
      <div class="min-w-0">
        <p class="text-sm text-n-slate-12 truncate">
          {{ participant.display_name }}
        </p>
        <p v-if="participant.phone" class="text-xs text-n-slate-11 truncate">
          {{ formatPhone(participant.phone) }}
        </p>
      </div>
    </div>
  </div>
</template>
