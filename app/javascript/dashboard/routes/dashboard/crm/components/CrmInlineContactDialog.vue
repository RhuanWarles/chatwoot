<script setup>
import { computed, reactive, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { DuplicateContactException } from 'shared/helpers/CustomErrors';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import PhoneNumberInput from 'dashboard/components-next/phonenumberinput/PhoneNumberInput.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import contactsAPI from 'dashboard/api/contacts';
import { formatContactPhone } from './contactHelpers';

const emit = defineEmits(['created']);
const store = useStore();
const { t } = useI18n();
const dialog = ref(null);
const form = reactive({ name: '', phoneNumber: '', email: '' });
const saving = ref(false);
const errorMessage = ref('');
const duplicate = ref(null);
const v$ = useVuelidate({ name: { required }, email: { email } }, form);
const invalid = computed(() => v$.value.$invalid);

const open = name => {
  Object.assign(form, { name, phoneNumber: '', email: '' });
  errorMessage.value = '';
  duplicate.value = null;
  v$.value.$reset();
  dialog.value.open();
};

const selectDuplicate = () => {
  emit('created', duplicate.value);
  dialog.value.close();
};

const createContact = async () => {
  if (saving.value) return;
  saving.value = true;
  if (!(await v$.value.$validate())) {
    saving.value = false;
    return;
  }
  errorMessage.value = '';
  duplicate.value = null;
  try {
    const contact = await store.dispatch('contacts/create', {
      name: form.name.trim(),
      ...(form.phoneNumber ? { phoneNumber: form.phoneNumber } : {}),
      ...(form.email ? { email: form.email.trim() } : {}),
    });
    emit('created', contact);
    dialog.value.close();
  } catch (error) {
    errorMessage.value = t('CRM_CONTACT_PICKER.CREATE_ERROR');
    if (error instanceof DuplicateContactException) {
      try {
        const identifiers = [form.phoneNumber, form.email.trim()].filter(
          Boolean
        );
        const responses = await Promise.all(
          identifiers.map(identifier => contactsAPI.search(identifier, 1))
        );
        duplicate.value =
          responses
            .flatMap(response => response.data.payload)
            .find(
              contact =>
                (form.phoneNumber &&
                  contact.phone_number === form.phoneNumber) ||
                (form.email.trim() &&
                  contact.email?.toLowerCase() ===
                    form.email.trim().toLowerCase())
            ) || null;
        if (duplicate.value)
          errorMessage.value = t('CRM_CONTACT_PICKER.DUPLICATE');
      } catch {
        errorMessage.value = t('CRM_CONTACT_PICKER.CREATE_ERROR');
      }
    }
  } finally {
    saving.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialog"
    :title="t('CRM_CONTACT_PICKER.NEW_CONTACT')"
    :confirm-button-label="
      saving
        ? t('CRM_CONTACT_PICKER.CREATING')
        : t('CRM_CONTACT_PICKER.CREATE_SELECT')
    "
    :cancel-button-label="t('CRM.CANCEL')"
    :disable-confirm-button="invalid"
    :is-loading="saving"
    @confirm="createContact"
  >
    <Input
      v-model="form.name"
      :label="t('CRM_CONTACT_PICKER.NAME')"
      :disabled="saving"
      :message="v$.name.$error ? t('CRM_CONTACT_PICKER.NAME_REQUIRED') : ''"
      :message-type="v$.name.$error ? 'error' : 'info'"
      autofocus
    />
    <div class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">{{
        t('CRM_CONTACT_PICKER.PHONE')
      }}</span>
      <PhoneNumberInput
        v-model="form.phoneNumber"
        :disabled="saving"
        :placeholder="t('CRM_CONTACT_PICKER.PHONE')"
      />
    </div>
    <Input
      v-model="form.email"
      type="email"
      :label="t('CRM_CONTACT_PICKER.EMAIL')"
      :disabled="saving"
      :message="v$.email.$error ? t('CRM_CONTACT_PICKER.EMAIL_INVALID') : ''"
      :message-type="v$.email.$error ? 'error' : 'info'"
    />
    <p v-if="errorMessage" role="alert" class="mb-0 text-sm text-n-ruby-9">
      {{ errorMessage }}
    </p>
    <div v-if="duplicate" class="flex flex-col gap-2">
      <span class="text-sm text-n-slate-12">{{ duplicate.name }}</span>
      <span
        v-if="duplicate.phone_number"
        dir="ltr"
        class="text-xs text-n-slate-11"
      >
        {{ formatContactPhone(duplicate.phone_number) }}
      </span>
      <span v-if="duplicate.email" class="text-xs text-n-slate-11">{{
        duplicate.email
      }}</span>
      <Button
        type="button"
        :label="t('CRM_CONTACT_PICKER.SELECT_EXISTING')"
        @click="selectDuplicate"
      />
    </div>
  </Dialog>
</template>
