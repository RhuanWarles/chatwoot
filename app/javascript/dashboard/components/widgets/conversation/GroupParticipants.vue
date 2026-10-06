<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import CaretAnchoredPicker from 'dashboard/components-next/preview-picker/CaretAnchoredPicker.vue';
import groupParticipantsAPI from 'dashboard/api/conversations/groupParticipantsAPI';

const props = defineProps({
  conversationId: { type: Number, required: true },
  caretPosition: { type: Object, default: null },
  searchKey: { type: String, default: '' },
});

const emit = defineEmits(['select', 'close', 'removeTrigger']);
const { t } = useI18n();
const participants = ref([]);
const searchQuery = ref(props.searchKey);
const loading = ref(false);
const loaded = ref(false);

watch(
  () => props.searchKey,
  value => {
    searchQuery.value = value;
  }
);

const load = async () => {
  if (loaded.value || loading.value) return;
  loading.value = true;
  try {
    participants.value =
      (await groupParticipantsAPI(props.conversationId).get()).data
        .participants || [];
    loaded.value = true;
  } catch {
    emit('close');
  } finally {
    loading.value = false;
  }
};

const formatPhone = phone => {
  if (!phone) return '';
  if (/^55\d{11}$/.test(phone)) {
    return `+55 ${phone.slice(2, 4)} ${phone.slice(4, 9)}-${phone.slice(9)}`;
  }
  return `+${phone}`;
};

const items = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  return participants.value
    .filter(participant =>
      [
        participant.display_name,
        participant.contact_name,
        participant.whatsapp_name,
        participant.phone,
      ]
        .filter(Boolean)
        .some(value => String(value).toLowerCase().includes(query))
    )
    .map(participant => ({
      id: participant.lid || participant.jid,
      record: participant,
      label: participant.display_name,
      title: participant.display_name,
      subtitle: formatPhone(participant.phone),
    }));
});

const onSelect = item => emit('select', item.record);
onMounted(load);
</script>

<template>
  <CaretAnchoredPicker
    v-model:search="searchQuery"
    :caret-position="caretPosition"
    :items="items"
    :is-loading="loading"
    :search-placeholder="t('CONVERSATION.GROUP_PARTICIPANTS.SEARCH')"
    :empty-label="t('CONVERSATION.GROUP_PARTICIPANTS.EMPTY')"
    @select="onSelect"
    @close="emit('close')"
    @remove-trigger="emit('removeTrigger')"
  >
    <template #leading="{ item }">
      <Avatar
        :src="item.record.avatar_url"
        :name="item.label"
        :size="24"
        rounded-full
        class="flex-shrink-0"
      />
    </template>
  </CaretAnchoredPicker>
</template>
