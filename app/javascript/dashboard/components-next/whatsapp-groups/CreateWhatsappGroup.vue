<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import WhatsappGroupDialog from './WhatsappGroupDialog.vue';
import whatsappGroupsAPI from 'dashboard/api/whatsappGroups';

const props = defineProps({ collapsed: { type: Boolean, default: false } });
const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');
const inboxes = ref([]);
const dialog = ref(null);
watch(
  accountId,
  async value => {
    inboxes.value = [];
    if (!value) return;
    try {
      const response = await whatsappGroupsAPI.get();
      if (value === accountId.value) inboxes.value = response.data.inboxes;
    } catch {
      inboxes.value = [];
    }
  },
  { immediate: true }
);
</script>

<template>
  <div class="min-w-0">
    <slot
      name="trigger"
      :available="!!inboxes.length"
      :open="() => dialog?.open()"
    >
      <Button
        v-if="inboxes.length"
        type="button"
        variant="ghost"
        color="slate"
        icon="i-lucide-users-round"
        :label="props.collapsed ? '' : t('WHATSAPP_GROUPS.NEW_GROUP')"
        :aria-label="t('WHATSAPP_GROUPS.NEW_GROUP')"
        @click="dialog.open()"
      />
    </slot>
    <WhatsappGroupDialog
      v-if="inboxes.length"
      ref="dialog"
      :key="accountId"
      :inboxes="inboxes"
    />
  </div>
</template>
