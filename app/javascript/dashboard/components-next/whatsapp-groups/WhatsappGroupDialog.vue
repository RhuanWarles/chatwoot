<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import GroupParticipantPicker from './GroupParticipantPicker.vue';
import whatsappGroupsAPI from 'dashboard/api/whatsappGroups';
import groupParticipantsAPI from 'dashboard/api/conversations/groupParticipantsAPI';

const props = defineProps({
  inboxes: { type: Array, default: () => [] },
  conversationId: { type: [Number, String], default: null },
  existingParticipants: { type: Array, default: () => [] },
});
const emit = defineEmits(['added']);
const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const dialog = ref(null);
const subject = ref('');
const inboxId = ref('');
const selected = ref([]);
const busy = ref(false);
const error = ref('');
const requestId = ref('');
const attempted = ref(false);
const adding = computed(() => props.conversationId !== null);
const inboxOptions = computed(() =>
  props.inboxes.map(inbox => ({ value: inbox.id, label: inbox.name }))
);
const valid = computed(
  () =>
    selected.value.length &&
    (adding.value || (subject.value.trim() && inboxId.value))
);
const open = () => {
  if (!attempted.value) {
    subject.value = '';
    inboxId.value = props.inboxes[0]?.id || '';
    selected.value = [];
    error.value = '';
    requestId.value = crypto.randomUUID();
  }
  dialog.value.open();
};
const submit = async () => {
  if (busy.value || !valid.value) return;
  busy.value = true;
  attempted.value = true;
  error.value = '';
  try {
    const participants = selected.value.map(item => item.phone);
    if (adding.value) {
      const response = await groupParticipantsAPI(props.conversationId).create({
        participants,
      });
      emit('added', response.data.participants);
    } else {
      const response = await whatsappGroupsAPI.create({
        inbox_id: inboxId.value,
        subject: subject.value.trim(),
        participants,
        request_id: requestId.value,
      });
      await router.push({
        name: 'inbox_conversation',
        params: {
          accountId: route.params.accountId,
          conversation_id: response.data.conversation_id,
        },
      });
    }
    attempted.value = false;
    dialog.value.close();
  } catch (exception) {
    error.value =
      exception.response?.data?.error || t('WHATSAPP_GROUPS.OPERATION_ERROR');
    const code = exception.response?.data?.error_code;
    // Keep the same creation token after ambiguous failures, including browser/network timeouts.
    if (
      adding.value ||
      (code && !['creation_uncertain', 'request_conflict'].includes(code))
    ) {
      attempted.value = false;
      requestId.value = crypto.randomUUID();
    }
  } finally {
    busy.value = false;
  }
};
defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    :title="
      adding
        ? t('WHATSAPP_GROUPS.ADD_PARTICIPANT')
        : t('WHATSAPP_GROUPS.NEW_GROUP')
    "
    :confirm-button-label="
      busy
        ? t('WHATSAPP_GROUPS.SAVING')
        : adding
          ? t('WHATSAPP_GROUPS.ADD')
          : t('WHATSAPP_GROUPS.CREATE')
    "
    :disable-confirm-button="!valid"
    :is-loading="busy"
    @confirm="submit"
  >
    <template v-if="!adding">
      <Input
        v-model="subject"
        :label="t('WHATSAPP_GROUPS.NAME')"
        :disabled="busy || attempted"
        maxlength="100"
      />
      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">{{
          t('WHATSAPP_GROUPS.INBOX')
        }}</label>
        <ComboBox
          v-model="inboxId"
          :options="inboxOptions"
          :disabled="busy || attempted"
          :placeholder="t('WHATSAPP_GROUPS.INBOX')"
        />
      </div>
    </template>
    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-n-slate-12">{{
        t('WHATSAPP_GROUPS.PARTICIPANTS')
      }}</label>
      <GroupParticipantPicker
        v-model="selected"
        :existing-participants="existingParticipants"
        :disabled="busy || (!adding && attempted)"
      />
    </div>
    <p v-if="error" role="alert" class="mb-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
  </Dialog>
</template>
