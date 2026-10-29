<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';

import { lostReasonsAPI } from 'dashboard/api/crm';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const { t } = useI18n();

const reasons = ref([]);
const loading = ref(false);
const saving = ref(false);
const error = ref('');
const newName = ref('');
const editingId = ref(null);
const editName = ref('');

const fail = () => {
  error.value = t('CRM.LOST_REASON_SAVE_ERROR');
};

const load = async () => {
  loading.value = true;
  error.value = '';
  try {
    reasons.value = (await lostReasonsAPI.get()).data;
  } catch {
    error.value = t('CRM.LOST_REASON_LOAD_ERROR');
  } finally {
    loading.value = false;
  }
};

const replace = updated => {
  reasons.value = reasons.value.map(item =>
    item.id === updated.id ? updated : item
  );
};

const create = async () => {
  const name = newName.value.trim();
  if (!name || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await lostReasonsAPI.create({
      lost_reason: { name, position: reasons.value.length + 1 },
    });
    reasons.value = [...reasons.value, data];
    newName.value = '';
  } catch {
    fail();
  } finally {
    saving.value = false;
  }
};

const startEdit = reason => {
  editingId.value = reason.id;
  editName.value = reason.name;
};

const saveEdit = async reason => {
  const name = editName.value.trim();
  if (!name || saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await lostReasonsAPI.update(reason.id, {
      lost_reason: { name },
    });
    replace(data);
    editingId.value = null;
  } catch {
    fail();
  } finally {
    saving.value = false;
  }
};

const toggleActive = async reason => {
  if (saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await lostReasonsAPI.update(reason.id, {
      lost_reason: { active: !reason.active },
    });
    replace(data);
  } catch {
    fail();
  } finally {
    saving.value = false;
  }
};

const remove = async reason => {
  if (saving.value) return;
  saving.value = true;
  error.value = '';
  try {
    const { data } = await lostReasonsAPI.delete(reason.id);
    // A reason that deals already carry is only deactivated, and the server answers with it.
    if (data?.id) replace(data);
    else reasons.value = reasons.value.filter(item => item.id !== reason.id);
  } catch {
    fail();
  } finally {
    saving.value = false;
  }
};

// Only the reasons that changed place are saved, each with its new position.
const saveOrder = async ordered => {
  const previous = reasons.value;
  const moved = ordered
    .map((reason, index) => ({ reason, position: index + 1 }))
    .filter(({ reason, position }) => reason.position !== position);
  if (!moved.length) return;
  reasons.value = ordered.map((reason, index) => ({
    ...reason,
    position: index + 1,
  }));
  saving.value = true;
  error.value = '';
  try {
    await Promise.all(
      moved.map(({ reason, position }) =>
        lostReasonsAPI.update(reason.id, { lost_reason: { position } })
      )
    );
  } catch {
    reasons.value = previous;
    fail();
  } finally {
    saving.value = false;
  }
};

const move = (reason, offset) => {
  const ordered = [...reasons.value];
  const from = ordered.findIndex(item => item.id === reason.id);
  const to = from + offset;
  if (to < 0 || to >= ordered.length) return;
  [ordered[from], ordered[to]] = [ordered[to], ordered[from]];
  saveOrder(ordered);
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
          {{ t('CRM.LOST_REASONS_TITLE') }}
        </h1>
        <p class="mt-1 text-sm text-n-slate-11">
          {{ t('CRM.LOST_REASONS_SUBTITLE') }}
        </p>
      </header>

      <form
        class="flex flex-col gap-3 rounded-xl border border-n-weak bg-n-solid-1 p-3 sm:flex-row sm:items-end"
        data-test="new-lost-reason"
        @submit.prevent="create"
      >
        <div class="min-w-0 flex-1">
          <Input
            v-model="newName"
            :label="t('CRM.LOST_REASON_NAME')"
            :placeholder="t('CRM.LOST_REASON_NAME_PLACEHOLDER')"
            maxlength="80"
          />
        </div>
        <Button
          type="submit"
          size="sm"
          icon="i-lucide-plus"
          :label="t('CRM.LOST_REASON_ADD')"
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
        {{ t('CRM.LOST_REASONS_LOADING') }}
      </div>

      <Draggable
        v-else-if="reasons.length"
        :model-value="reasons"
        item-key="id"
        tag="ul"
        handle=".lost-reason-handle"
        class="m-0 flex list-none flex-col overflow-hidden rounded-xl border border-n-weak bg-n-solid-1 p-0"
        :aria-label="t('CRM.LOST_REASONS_TITLE')"
        @update:model-value="saveOrder"
      >
        <template #item="{ element: reason, index }">
          <li
            class="flex flex-wrap items-center gap-3 border-b border-n-weak px-4 py-3 last:border-b-0"
            data-test="lost-reason"
          >
            <span
              class="lost-reason-handle i-lucide-grip-vertical size-4 shrink-0 cursor-grab text-n-slate-10"
              :title="t('CRM.LOST_REASON_DRAG')"
              aria-hidden="true"
            />
            <template v-if="editingId === reason.id">
              <div class="min-w-0 flex-1">
                <Input
                  v-model="editName"
                  :aria-label="t('CRM.LOST_REASON_NAME')"
                  maxlength="80"
                  @enter="saveEdit(reason)"
                />
              </div>
              <Button
                size="sm"
                :label="t('CRM.LOST_REASON_SAVE')"
                :disabled="!editName.trim() || saving"
                @click="saveEdit(reason)"
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
                class="min-w-0 flex-1 truncate text-sm font-medium"
                :class="reason.active ? 'text-n-slate-12' : 'text-n-slate-10'"
              >
                {{ reason.name }}
              </span>
              <span
                v-if="!reason.active"
                class="rounded-full bg-n-alpha-2 px-2 py-0.5 text-label-small text-n-slate-11"
              >
                {{ t('CRM.LOST_REASON_INACTIVE') }}
              </span>
              <Button
                size="xs"
                variant="ghost"
                color="slate"
                icon="i-lucide-arrow-up"
                data-test="move-up"
                :aria-label="t('CRM.LOST_REASON_MOVE_UP')"
                :disabled="saving || index === 0"
                @click="move(reason, -1)"
              />
              <Button
                size="xs"
                variant="ghost"
                color="slate"
                icon="i-lucide-arrow-down"
                data-test="move-down"
                :aria-label="t('CRM.LOST_REASON_MOVE_DOWN')"
                :disabled="saving || index === reasons.length - 1"
                @click="move(reason, 1)"
              />
              <Button
                size="xs"
                variant="ghost"
                color="slate"
                icon="i-lucide-pencil"
                :aria-label="t('CRM.LOST_REASON_EDIT')"
                @click="startEdit(reason)"
              />
              <Button
                size="xs"
                variant="ghost"
                color="slate"
                :label="
                  reason.active
                    ? t('CRM.LOST_REASON_DEACTIVATE')
                    : t('CRM.LOST_REASON_ACTIVATE')
                "
                :disabled="saving"
                @click="toggleActive(reason)"
              />
              <Button
                size="xs"
                variant="ghost"
                color="ruby"
                icon="i-lucide-trash-2"
                data-test="remove"
                :aria-label="t('CRM.LOST_REASON_REMOVE')"
                :disabled="saving"
                @click="remove(reason)"
              />
            </template>
          </li>
        </template>
      </Draggable>

      <div
        v-else
        class="rounded-xl border border-dashed border-n-weak px-4 py-12 text-center text-sm text-n-slate-11"
      >
        {{ t('CRM.LOST_REASONS_EMPTY') }}
      </div>
    </div>
  </main>
</template>
