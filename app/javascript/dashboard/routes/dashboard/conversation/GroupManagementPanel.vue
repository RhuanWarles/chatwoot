<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import mutationTypes from 'dashboard/store/mutation-types';
import Avatar from 'next/avatar/Avatar.vue';
import Button from 'next/button/Button.vue';
import Input from 'next/input/Input.vue';
import Dialog from 'next/dialog/Dialog.vue';
import Popover from 'next/popover/Popover.vue';
import DropdownMenu from 'next/dropdown-menu/DropdownMenu.vue';
import WhatsappGroupDialog from 'dashboard/components-next/whatsapp-groups/WhatsappGroupDialog.vue';
import groupAPI from 'dashboard/api/conversations/groupManagementAPI';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});
const { t } = useI18n();
const store = useStore();
const group = ref(null);
const loading = ref(false);
const busy = ref(false);
const error = ref('');
const editDialog = ref(null);
const pictureInput = ref(null);
const savingInformation = ref(false);
const name = ref('');
const picture = ref(null);
const preview = ref('');
const addDialog = ref(null);
const confirmDialog = ref(null);
const confirmation = ref(null);
let loadVersion = 0;
const MAX_PICTURE_SIZE = 5 * 1024 * 1024;
const PICTURE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const participants = computed(() => group.value?.participants || []);
const confirmationTitle = computed(() =>
  confirmation.value?.operation === 'leave'
    ? t('WHATSAPP_GROUPS.ADMIN.LEAVE')
    : t('WHATSAPP_GROUPS.ADMIN.REMOVE_CONFIRM', {
        name: confirmation.value?.participant?.display_name,
      })
);
const clearPicture = () => {
  if (preview.value) URL.revokeObjectURL(preview.value);
  preview.value = '';
  picture.value = null;
};
const load = async () => {
  loadVersion += 1;
  const version = loadVersion;
  loading.value = true;
  group.value = null;
  error.value = '';
  editDialog.value?.close();
  clearPicture();
  try {
    const response = await groupAPI(props.conversationId).get();
    if (version === loadVersion) group.value = response.data;
  } catch (exception) {
    if (version === loadVersion)
      error.value =
        exception.response?.data?.error || t('WHATSAPP_GROUPS.OPERATION_ERROR');
  } finally {
    if (version === loadVersion) loading.value = false;
  }
};
const mutate = async (operation, body = {}) => {
  if (busy.value) return false;
  const { conversationId } = props;
  busy.value = true;
  error.value = '';
  try {
    const api = groupAPI(conversationId);
    let response;
    if (operation === 'leave') response = await api.leave();
    else if (operation === 'participants')
      response = await api.participants(body);
    else response = await api.update(body);
    if (conversationId !== props.conversationId) return false;
    group.value = response.data;
    store.commit(mutationTypes.UPDATE_CONVERSATION, {
      id: Number(conversationId),
      additional_attributes: response.data.additional_attributes,
      can_reply: response.data.can_reply,
    });
    await store.dispatch('updateConversationContact', {
      conversationId: Number(conversationId),
      ...response.data.contact,
    });
    confirmDialog.value.close();
    await store.dispatch('getConversation', conversationId);
    return true;
  } catch (exception) {
    if (conversationId === props.conversationId)
      error.value =
        exception.response?.data?.error || t('WHATSAPP_GROUPS.OPERATION_ERROR');
    return false;
  } finally {
    busy.value = false;
  }
};
const choosePicture = event => {
  if (busy.value) return;
  clearPicture();
  const file = event.target.files[0];
  event.target.value = '';
  if (!file) return;
  if (
    !PICTURE_TYPES.includes(file.type) ||
    !file.size ||
    file.size > MAX_PICTURE_SIZE
  ) {
    error.value = t('WHATSAPP_GROUPS.ADMIN.INVALID_PICTURE');
    return;
  }
  error.value = '';
  picture.value = file;
  preview.value = URL.createObjectURL(file);
};
const informationChanged = computed(
  () => Boolean(picture.value) || name.value.trim() !== group.value?.name
);
const openInformation = () => {
  if (busy.value || savingInformation.value) return;
  clearPicture();
  error.value = '';
  name.value = group.value.name;
  editDialog.value.open();
};
const cancelInformation = () => {
  if (savingInformation.value) return;
  clearPicture();
  name.value = group.value?.name || '';
  error.value = '';
};
const saveInformation = async () => {
  if (
    busy.value ||
    savingInformation.value ||
    !name.value.trim() ||
    !informationChanged.value
  )
    return;
  savingInformation.value = true;
  const { conversationId } = props;
  try {
    if (name.value.trim() !== group.value.name) {
      const saved = await mutate('update', { subject: name.value.trim() });
      if (!saved || conversationId !== props.conversationId) return;
    }
    if (picture.value) {
      const body = new FormData();
      body.append('picture', picture.value);
      const saved = await mutate('update', body);
      if (!saved || conversationId !== props.conversationId) return;
    }
    clearPicture();
    editDialog.value.close();
  } finally {
    savingInformation.value = false;
  }
};
const actions = participant => [
  {
    action: participant.admin ? 'demote' : 'promote',
    label: participant.admin
      ? t('WHATSAPP_GROUPS.ADMIN.DEMOTE')
      : t('WHATSAPP_GROUPS.ADMIN.PROMOTE'),
    icon: 'i-lucide-shield',
  },
  {
    action: 'remove',
    label: t('WHATSAPP_GROUPS.ADMIN.REMOVE'),
    icon: 'i-lucide-user-minus',
  },
];
const participantAction = (action, participant, hide) => {
  hide();
  if (busy.value) return;
  if (action === 'remove') {
    confirmation.value = { operation: 'participants', participant };
    confirmDialog.value.open();
  } else {
    mutate('participants', {
      operation: action,
      participant_id: participant.lid || participant.jid,
    });
  }
};
const confirm = () => {
  if (confirmation.value.operation === 'leave') return mutate('leave');
  return mutate('participants', {
    operation: 'remove',
    confirmed: true,
    participant_id:
      confirmation.value.participant.lid || confirmation.value.participant.jid,
  });
};
const leave = () => {
  confirmation.value = { operation: 'leave' };
  confirmDialog.value.open();
};
watch(() => props.conversationId, load, { immediate: true });
onBeforeUnmount(clearPicture);
</script>

<template>
  <div class="flex flex-col gap-3 px-1 pb-1 min-w-0">
    <p v-if="loading" class="text-sm text-n-slate-11">
      {{ t('CONVERSATION.GROUP_PARTICIPANTS.LOADING') }}
    </p>
    <template v-if="group">
      <section class="min-w-0" :aria-label="t('WHATSAPP_GROUPS.ADMIN.INFO')">
        <p v-if="group.left" role="status" class="text-sm text-n-ruby-11">
          {{ t('WHATSAPP_GROUPS.ADMIN.LEFT') }}
        </p>
        <div class="flex items-center gap-2 min-w-0">
          <Avatar
            :src="group.picture_url || ''"
            :name="group.name"
            :size="36"
            class="shrink-0"
          />
          <div class="min-w-0 flex-1">
            <p
              class="mb-0 text-sm font-medium text-n-slate-12 break-words [overflow-wrap:anywhere]"
            >
              {{ group.name }}
            </p>
            <Button
              v-if="group.can_manage && !group.left"
              variant="link"
              size="xs"
              :label="t('WHATSAPP_GROUPS.ADMIN.EDIT_INFORMATION')"
              :disabled="busy || savingInformation"
              @click="openInformation"
            />
          </div>
        </div>
      </section>
      <section
        class="border-t border-n-weak pt-3 min-w-0"
        :aria-label="
          t('WHATSAPP_GROUPS.ADMIN.PARTICIPANTS', {
            count: participants.length,
          })
        "
      >
        <div class="flex items-center justify-between gap-2 min-w-0 mb-1">
          <h4 class="mb-0 text-xs font-medium text-n-slate-12">
            {{
              t('WHATSAPP_GROUPS.ADMIN.PARTICIPANTS', {
                count: participants.length,
              })
            }}
          </h4>
          <Button
            v-if="group.instance_member && !group.left"
            variant="ghost"
            size="xs"
            icon="i-lucide-plus"
            :label="t('WHATSAPP_GROUPS.ADMIN.ADD')"
            :disabled="busy"
            @click="addDialog.open()"
          />
        </div>
        <div
          v-for="participant in participants"
          :key="participant.lid || participant.jid"
          class="flex items-center min-w-0 gap-2 py-2"
        >
          <Avatar
            :src="participant.avatar_url || ''"
            :name="participant.display_name"
            :size="28"
          />
          <div class="min-w-0 flex-1">
            <p class="mb-0 text-sm text-n-slate-12 truncate">
              {{ participant.display_name }}
            </p>
            <p
              v-if="participant.phone"
              class="mb-0 text-xs text-n-slate-11 truncate"
              dir="ltr"
            >
              {{ `+${participant.phone}` }}
            </p>
            <div class="flex flex-wrap items-center gap-1 mt-0.5">
              <span
                v-if="participant.admin"
                class="text-xs rounded px-1 bg-n-alpha-2 text-n-slate-11"
              >
                {{ t('WHATSAPP_GROUPS.ADMIN.ADMIN') }}
              </span>
              <span
                v-if="participant.is_self"
                class="text-xs rounded px-1 bg-n-alpha-2 text-n-slate-11"
              >
                {{ t('WHATSAPP_GROUPS.ADMIN.SELF') }}
              </span>
            </div>
          </div>
          <Popover
            v-if="
              group.can_manage &&
              !participant.is_self &&
              !participant.super_admin &&
              participant.phone
            "
            align="end"
          >
            <Button
              icon="i-lucide-ellipsis-vertical"
              variant="ghost"
              size="xs"
              :disabled="busy"
              :aria-label="t('WHATSAPP_GROUPS.ADMIN.ACTIONS')"
            />
            <template #content="{ hide }">
              <DropdownMenu
                class="!relative w-56 max-w-[calc(100vw-2rem)]"
                :menu-items="actions(participant)"
                @action="participantAction($event.action, participant, hide)"
              />
            </template>
          </Popover>
        </div>
      </section>
      <WhatsappGroupDialog
        ref="addDialog"
        :key="conversationId"
        :conversation-id="conversationId"
        :existing-participants="participants"
        @added="load"
      />
      <div
        v-if="group.can_leave && !group.left"
        class="border-t border-n-weak pt-3 mt-1"
      >
        <p class="mb-1 text-xs font-medium text-n-ruby-11">
          {{ t('WHATSAPP_GROUPS.ADMIN.DANGER') }}
        </p>
        <Button
          color="ruby"
          variant="ghost"
          size="sm"
          icon="i-lucide-log-out"
          :label="t('WHATSAPP_GROUPS.ADMIN.LEAVE')"
          :disabled="busy"
          @click="leave"
        />
      </div>
    </template>
    <p v-if="error" role="alert" class="mb-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <Button
      v-if="!group && !loading"
      variant="ghost"
      size="sm"
      :label="t('WHATSAPP_GROUPS.ADMIN.REFRESH')"
      @click="load"
    />
    <Dialog
      ref="editDialog"
      width="sm"
      :title="t('WHATSAPP_GROUPS.ADMIN.EDIT_TITLE')"
      :show-cancel-button="false"
      :show-confirm-button="false"
      @confirm="saveInformation"
      @close="cancelInformation"
    >
      <div class="flex flex-col gap-4 min-w-0">
        <div class="flex flex-col gap-2">
          <p class="mb-0 text-sm font-medium text-n-slate-12">
            {{ t('WHATSAPP_GROUPS.ADMIN.PHOTO') }}
          </p>
          <div class="flex items-center gap-3">
            <Avatar
              :src="preview || group?.picture_url || ''"
              :name="group?.name || ''"
              :size="56"
            />
            <Button
              variant="faded"
              size="sm"
              type="button"
              icon="i-lucide-image"
              :label="t('WHATSAPP_GROUPS.ADMIN.PICTURE')"
              :disabled="savingInformation"
              @click="pictureInput.click()"
            />
            <input
              ref="pictureInput"
              type="file"
              class="hidden"
              accept="image/jpeg,image/png,image/webp"
              :disabled="savingInformation"
              :aria-label="t('WHATSAPP_GROUPS.ADMIN.PICTURE')"
              @change="choosePicture"
            />
          </div>
        </div>
        <Input
          v-model="name"
          :label="t('WHATSAPP_GROUPS.NAME')"
          :disabled="savingInformation"
          maxlength="100"
        />
        <p v-if="error" role="alert" class="mb-0 text-sm text-n-ruby-11">
          {{ error }}
        </p>
      </div>
      <template #footer>
        <div class="flex items-center justify-end gap-2">
          <Button
            variant="faded"
            type="button"
            :label="t('WHATSAPP_GROUPS.ADMIN.CANCEL')"
            :disabled="savingInformation"
            @click="editDialog.close()"
          />
          <Button
            type="submit"
            :label="t('WHATSAPP_GROUPS.ADMIN.SAVE')"
            :is-loading="savingInformation"
            :disabled="
              busy || savingInformation || !name.trim() || !informationChanged
            "
          />
        </div>
      </template>
    </Dialog>
    <Dialog
      ref="confirmDialog"
      type="alert"
      :title="confirmationTitle"
      :description="
        confirmation?.operation === 'leave'
          ? t('WHATSAPP_GROUPS.ADMIN.LEAVE_WARNING')
          : ''
      "
      :confirm-button-label="
        busy
          ? t('WHATSAPP_GROUPS.SAVING')
          : confirmation?.operation === 'leave'
            ? t('WHATSAPP_GROUPS.ADMIN.LEAVE')
            : t('WHATSAPP_GROUPS.ADMIN.REMOVE')
      "
      :disable-confirm-button="busy"
      :is-loading="busy"
      @confirm="confirm"
    >
      <p v-if="error" role="alert" class="mb-0 text-sm text-n-ruby-11">
        {{ error }}
      </p>
    </Dialog>
  </div>
</template>
