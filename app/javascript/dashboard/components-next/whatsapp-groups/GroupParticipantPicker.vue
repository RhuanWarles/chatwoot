<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import contactsAPI from 'dashboard/api/contacts';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  existingParticipants: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
});
const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
const query = ref('');
const contacts = ref([]);
const failed = ref(false);
const selectionVersion = ref(0);
const { run, abort, isPending } = useAbortableRequest();
const phoneDigits = value => {
  if (!/^\+?[\d\s().-]+$/.test(value || '')) return '';
  const digits = value.replace(/\D/g, '');
  return /^[1-9]\d{9,14}$/.test(digits) ? digits : '';
};
const excluded = computed(() => {
  const existing = props.existingParticipants.flatMap(participant => [
    participant.phone,
    participant.jid?.replace(/@s\.whatsapp\.net$/, ''),
  ]);
  return new Set([...existing, ...props.modelValue.map(item => item.phone)]);
});
const options = computed(() => {
  const seen = new Set(excluded.value);
  const results = contacts.value.flatMap(contact => {
    const phone = phoneDigits(contact.phone_number);
    if (!phone || seen.has(phone)) return [];
    seen.add(phone);
    return [
      {
        value: phone,
        label:
          contact.name ||
          contact.additional_attributes?.whatsapp_name ||
          `+${phone}`,
        phone,
        avatar: contact.thumbnail,
      },
    ];
  });
  const manual = phoneDigits(query.value.trim());
  if (manual && !seen.has(manual)) {
    results.push({
      value: manual,
      phone: manual,
      label: t('WHATSAPP_GROUPS.USE_PHONE', { phone: `+${manual}` }),
    });
  }
  return results;
});
const search = async (value = '') => {
  query.value = value;
  failed.value = false;
  contacts.value = [];
  try {
    const response = await run(signal =>
      value.trim()
        ? contactsAPI.search(value.trim(), 1, 'name', '', { signal })
        : contactsAPI.get(1, 'name', '', { signal })
    );
    if (response) contacts.value = response.data.payload;
  } catch {
    failed.value = true;
  }
};
const select = value => {
  const item = options.value.find(option => option.value === value);
  if (!item || props.disabled) return;
  abort();
  emit('update:modelValue', [...props.modelValue, item]);
  selectionVersion.value += 1;
  query.value = '';
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <ComboBox
      :key="selectionVersion"
      :options="options"
      :disabled="disabled"
      :loading="isPending"
      :placeholder="t('WHATSAPP_GROUPS.SEARCH')"
      :search-placeholder="t('WHATSAPP_GROUPS.SEARCH')"
      use-api-results
      @open="search()"
      @search="search"
      @update:model-value="select"
    >
      <template #option="{ option }">
        <div class="flex items-center gap-2 min-w-0">
          <Avatar :name="option.label" :src="option.avatar || ''" :size="28" />
          <div class="min-w-0">
            <p class="mb-0 truncate text-n-slate-12">{{ option.label }}</p>
            <p class="mb-0 text-xs text-n-slate-11" dir="ltr">
              {{ `+${option.phone}` }}
            </p>
          </div>
        </div>
      </template>
      <template #empty>
        {{
          failed
            ? t('WHATSAPP_GROUPS.SEARCH_ERROR')
            : t('WHATSAPP_GROUPS.NO_CONTACTS')
        }}
      </template>
    </ComboBox>
    <p class="mb-0 text-xs text-n-slate-11">
      {{ t('WHATSAPP_GROUPS.PHONE_HINT') }}
    </p>
    <div
      v-for="item in modelValue"
      :key="item.phone"
      class="flex items-center gap-2 min-w-0 rounded-lg bg-n-alpha-2 p-2"
    >
      <Avatar :name="item.label" :src="item.avatar || ''" :size="28" />
      <div class="flex-1 min-w-0">
        <p class="mb-0 truncate text-sm text-n-slate-12">{{ item.label }}</p>
        <p class="mb-0 text-xs text-n-slate-11" dir="ltr">
          {{ `+${item.phone}` }}
        </p>
      </div>
      <Button
        type="button"
        variant="ghost"
        color="slate"
        size="xs"
        icon="i-lucide-x"
        :disabled="disabled"
        :aria-label="t('WHATSAPP_GROUPS.REMOVE_SELECTION')"
        @click="
          emit(
            'update:modelValue',
            modelValue.filter(selected => selected.phone !== item.phone)
          )
        "
      />
    </div>
  </div>
</template>
