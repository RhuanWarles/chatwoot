<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import { segmentsAPI } from 'dashboard/api/crm';
import Button from 'dashboard/components-next/button/Button.vue';
import ColorPicker from 'dashboard/components-next/colorpicker/ColorPicker.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const DEFAULT_COLOR = '#1f93ff';
const { t } = useI18n();

const segments = ref([]);
const loading = ref(false);
const saving = ref(false);
const error = ref('');
const newName = ref('');
const newColor = ref(DEFAULT_COLOR);
const editingId = ref(null);
const editName = ref('');
const editColor = ref(DEFAULT_COLOR);

const fail = () => {
  error.value = t('CRM.SEGMENT_SAVE_ERROR');
};

const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    segments.value = (await segmentsAPI.get()).data;
  } catch {
    error.value = t('CRM.SEGMENT_LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};

const create = async () => {
  const name = newName.value.trim();
  if (!name || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await segmentsAPI.create({
      segment: { name, color: newColor.value },
    });
    segments.value = [...segments.value, data];
    newName.value = '';
  } catch {
    fail();
  } finally {
    saving.value = false;
  }
};

const startEdit = segment => {
  editingId.value = segment.id;
  editName.value = segment.name;
  editColor.value = segment.color || DEFAULT_COLOR;
};

const replace = updated => {
  segments.value = segments.value.map(item =>
    item.id === updated.id ? updated : item
  );
};

const saveEdit = async segment => {
  const name = editName.value.trim();
  if (!name || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await segmentsAPI.update(segment.id, {
      segment: { name, color: editColor.value },
    });
    replace(data);
    editingId.value = null;
  } catch {
    fail();
  } finally {
    saving.value = false;
  }
};

const toggleActive = async segment => {
  if (saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await segmentsAPI.update(segment.id, {
      segment: { active: !segment.active },
    });
    replace(data);
  } catch {
    fail();
  } finally {
    saving.value = false;
  }
};

const remove = async segment => {
  if (saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await segmentsAPI.delete(segment.id);
    // A segment that deals use is only deactivated, and the server answers with it.
    if (data?.id) replace(data);
    else segments.value = segments.value.filter(item => item.id !== segment.id);
  } catch {
    fail();
  } finally {
    saving.value = false;
  }
};

onMounted(load);
</script>

<template>
  <main
    class="flex h-full min-h-0 w-full min-w-0 flex-1 flex-col overflow-auto bg-n-background p-4 sm:p-6"
  >
    <div class="mx-auto flex w-full max-w-3xl flex-col gap-6">
      <header class="min-w-0">
        <h1 class="text-xl font-semibold text-n-slate-12">
          {{ t('CRM.SEGMENTS_TITLE') }}
        </h1>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ t('CRM.SEGMENTS_SUBTITLE') }}
        </p>
      </header>

      <form
        class="flex flex-col gap-3 rounded-2xl border border-n-container bg-n-surface-1 p-3 shadow-sm sm:flex-row sm:items-end"
        data-test="new-segment"
        @submit.prevent="create"
      >
        <div class="min-w-0 flex-1">
          <Input
            v-model="newName"
            :label="t('CRM.SEGMENT_NAME')"
            :placeholder="t('CRM.SEGMENT_NAME_PLACEHOLDER')"
            maxlength="80"
          />
        </div>
        <div class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('CRM.SEGMENT_COLOR') }}
          </span>
          <ColorPicker v-model="newColor" />
        </div>
        <Button
          type="submit"
          size="sm"
          icon="i-lucide-plus"
          :label="t('CRM.SEGMENT_ADD')"
          :disabled="!newName.trim() || saving"
        />
      </form>

      <p
        v-if="error"
        role="alert"
        class="rounded-lg bg-n-ruby-3 px-3 py-2 text-sm text-n-ruby-11"
      >
        {{ error }}
      </p>

      <div
        v-if="loading"
        class="flex items-center justify-center rounded-xl border border-n-weak bg-n-solid-1 px-4 py-12 text-sm text-n-slate-11"
      >
        {{ t('CRM.SEGMENTS_LOADING') }}
      </div>

      <ul
        v-else-if="segments.length"
        class="m-0 flex list-none flex-col overflow-hidden rounded-2xl border border-n-container bg-n-surface-1 p-0 shadow-sm"
        :aria-label="t('CRM.SEGMENTS_TITLE')"
      >
        <li
          v-for="segment in segments"
          :key="segment.id"
          class="flex flex-wrap items-center gap-3 border-b border-n-weak px-4 py-3 last:border-b-0"
          data-test="segment"
        >
          <template v-if="editingId === segment.id">
            <div class="min-w-0 flex-1">
              <Input
                v-model="editName"
                :aria-label="t('CRM.SEGMENT_NAME')"
                maxlength="80"
                @enter="saveEdit(segment)"
              />
            </div>
            <ColorPicker v-model="editColor" />
            <Button
              size="sm"
              :label="t('CRM.SEGMENT_SAVE')"
              :disabled="!editName.trim() || saving"
              @click="saveEdit(segment)"
            />
            <Button
              size="sm"
              variant="faded"
              color="slate"
              :label="t('CRM.CANCEL')"
              @click="editingId = null"
            />
          </template>
          <template v-else>
            <span
              class="size-3 shrink-0 rounded-full"
              :style="{ backgroundColor: segment.color || DEFAULT_COLOR }"
              aria-hidden="true"
            />
            <span
              class="min-w-0 flex-1 truncate text-sm font-medium"
              :class="segment.active ? 'text-n-slate-12' : 'text-n-slate-10'"
            >
              {{ segment.name }}
            </span>
            <span
              v-if="!segment.active"
              class="rounded-full bg-n-alpha-2 px-2 py-0.5 text-label-small text-n-slate-11"
            >
              {{ t('CRM.SEGMENT_INACTIVE') }}
            </span>
            <Button
              size="xs"
              variant="ghost"
              color="slate"
              icon="i-lucide-pencil"
              :aria-label="t('CRM.SEGMENT_EDIT')"
              @click="startEdit(segment)"
            />
            <Button
              size="xs"
              variant="ghost"
              color="slate"
              :label="
                segment.active
                  ? t('CRM.SEGMENT_DEACTIVATE')
                  : t('CRM.SEGMENT_ACTIVATE')
              "
              :disabled="saving"
              @click="toggleActive(segment)"
            />
            <Button
              size="xs"
              variant="ghost"
              color="ruby"
              icon="i-lucide-trash-2"
              :aria-label="t('CRM.SEGMENT_REMOVE')"
              :disabled="saving"
              @click="remove(segment)"
            />
          </template>
        </li>
      </ul>

      <div
        v-else
        class="rounded-xl border border-dashed border-n-weak px-4 py-12 text-center text-sm text-n-slate-11"
      >
        {{ t('CRM.SEGMENTS_EMPTY') }}
      </div>
    </div>
  </main>
</template>
