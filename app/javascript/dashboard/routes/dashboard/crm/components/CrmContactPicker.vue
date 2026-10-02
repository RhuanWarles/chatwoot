<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CrmInlineContactDialog from './CrmInlineContactDialog.vue';
import { formatContactPhone } from './contactHelpers';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import contactsAPI from 'dashboard/api/contacts';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';

const props = defineProps({
  modelValue: { type: [String, Number], default: '' },
  contact: { type: Object, default: null },
});
const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
const contacts = ref([]);
const selectedContact = ref(props.contact);
const searchQuery = ref('');
const searchFailed = ref(false);
const inlineDialog = ref(null);
const combo = ref(null);

const { run, abort, isPending } = useAbortableRequest();
const emptyMessage = computed(() => {
  if (isPending.value) return t('CRM_CONTACT_PICKER.SEARCHING');
  if (searchFailed.value) return t('CRM_CONTACT_PICKER.SEARCH_ERROR');
  return t('CRM_CONTACT_PICKER.NO_CONTACTS');
});

watch(
  () => props.contact,
  contact => {
    selectedContact.value = contact;
  }
);

const options = computed(() => {
  const results = [...contacts.value];
  if (
    !searchQuery.value &&
    selectedContact.value &&
    !results.some(contact => contact.id === selectedContact.value.id)
  ) {
    results.unshift(selectedContact.value);
  }
  return results.map(contact => ({
    value: contact.id,
    label: contact.name || t('CRM_CONTACT_PICKER.UNNAMED_CONTACT'),
    contact,
  }));
});

const searchContacts = async (query = '') => {
  searchQuery.value = query;
  contacts.value = [];
  searchFailed.value = false;
  try {
    const response = await run(signal =>
      query.trim()
        ? contactsAPI.search(query, 1, 'name', '', { signal })
        : contactsAPI.get(1, 'name', '', { signal })
    );
    if (response) contacts.value = response.data.payload;
  } catch {
    contacts.value = [];
    searchFailed.value = true;
    useAlert(t('CRM_CONTACT_PICKER.SEARCH_ERROR'));
  }
};

const selectContact = value => {
  abort();
  selectedContact.value =
    options.value.find(option => option.value === value)?.contact || null;
  emit('update:modelValue', value);
};
const openInlineContact = () => {
  combo.value.close();
  inlineDialog.value.open(searchQuery.value);
};
const onContactCreated = contact => {
  combo.value.close();
  abort();
  selectedContact.value = contact;
  contacts.value = [contact];
  searchQuery.value = '';
  emit('update:modelValue', contact.id);
};
</script>

<template>
  <ComboBox
    ref="combo"
    :model-value="modelValue"
    :options="options"
    :placeholder="t('CRM.CONTACT')"
    :display-label="selectedContact?.name || ''"
    :loading="isPending"
    :search-placeholder="t('CRM_CONTACT_PICKER.SEARCH_PLACEHOLDER')"
    use-api-results
    @open="searchContacts()"
    @search="searchContacts"
    @update:model-value="selectContact"
  >
    <template #empty>
      <div class="flex flex-col gap-2">
        <span>{{ emptyMessage }}</span>
        <Button
          v-if="searchQuery.trim() && !isPending && !searchFailed"
          type="button"
          variant="ghost"
          icon="i-lucide-plus"
          :label="t('CRM_CONTACT_PICKER.CREATE_NAMED', { name: searchQuery })"
          @click.stop="openInlineContact"
        />
      </div>
    </template>
    <template #option="{ option }">
      <div class="flex items-center min-w-0 gap-3">
        <Avatar
          :name="option.label"
          :src="option.contact.thumbnail || ''"
          :size="32"
          class="flex-shrink-0"
        />
        <div class="flex flex-col min-w-0 gap-0.5 text-start">
          <span class="font-medium text-n-slate-12 break-words">{{
            option.label
          }}</span>
          <span
            v-if="option.contact.phone_number"
            class="text-xs text-n-slate-11 break-words"
          >
            <span dir="ltr">{{
              formatContactPhone(option.contact.phone_number)
            }}</span>
          </span>
          <span
            v-if="option.contact.email"
            class="text-xs text-n-slate-11 break-all"
          >
            {{ option.contact.email }}
          </span>
        </div>
      </div>
    </template>
    <template #selected="{ label }">
      <span class="flex flex-col min-w-0 text-start">
        <span class="truncate">{{ label }}</span>
        <span
          v-if="
            selectedContact &&
            (selectedContact.phone_number || selectedContact.email)
          "
          class="text-xs font-normal text-n-slate-11 truncate"
        >
          <span v-if="selectedContact.phone_number" dir="ltr">{{
            formatContactPhone(selectedContact.phone_number)
          }}</span>
          <span v-else>{{ selectedContact.email }}</span>
        </span>
      </span>
    </template>
  </ComboBox>
  <CrmInlineContactDialog ref="inlineDialog" @created="onContactCreated" />
</template>
