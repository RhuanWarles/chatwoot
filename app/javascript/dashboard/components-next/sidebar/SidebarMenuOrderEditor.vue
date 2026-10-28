<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import Icon from 'next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { moveMenuItem } from 'dashboard/helper/sidebarMenuOrder';
import { useSidebarContext } from './provider';

const props = defineProps({
  // The tabs in the order they are shown now.
  items: { type: Array, required: true },
});

const emit = defineEmits(['change', 'reset', 'done']);

const { t } = useI18n();
const { isAllowed } = useSidebarContext();

// Same rule the sidebar uses to show a tab: it has a page the person can open, or one inside it.
const canSee = item => {
  if (!item.children?.length) return !!item.to && isAllowed(item.to);

  return item.children.some(child =>
    child.children
      ? child.children.some(sub => sub.to && isAllowed(sub.to))
      : child.to && isAllowed(child.to)
  );
};

const visibleItems = computed(() => props.items.filter(canSee));
const list = ref([]);

watch(
  visibleItems,
  items => {
    list.value = [...items];
  },
  { immediate: true }
);

const save = items => {
  list.value = items;
  emit(
    'change',
    items.map(item => item.name)
  );
};

const move = (index, step) => save(moveMenuItem(list.value, index, step));
</script>

<template>
  <div class="grid gap-2" data-test="menu-order-editor">
    <p class="px-1 m-0 text-xs text-n-slate-11">
      {{ t('SIDEBAR.ORGANIZE_MENU_HINT') }}
    </p>
    <Draggable
      :model-value="list"
      item-key="name"
      handle=".menu-order-handle"
      animation="200"
      ghost-class="opacity-50"
      class="flex flex-col gap-1"
      @update:model-value="save"
    >
      <template #item="{ element, index }">
        <div
          class="flex items-center gap-2 px-2 py-1.5 rounded-lg bg-n-alpha-1 text-n-slate-12"
          data-test="menu-order-item"
        >
          <span
            class="menu-order-handle i-lucide-grip-vertical size-4 shrink-0 cursor-grab text-n-slate-10"
            aria-hidden="true"
          />
          <Icon v-if="element.icon" :icon="element.icon" class="size-4" />
          <span class="flex-1 min-w-0 truncate">{{ element.label }}</span>
          <Button
            type="button"
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-chevron-up"
            :disabled="index === 0"
            :title="t('SIDEBAR.MOVE_UP')"
            :aria-label="t('SIDEBAR.MOVE_UP')"
            data-test="menu-order-up"
            @click="move(index, -1)"
          />
          <Button
            type="button"
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-chevron-down"
            :disabled="index === list.length - 1"
            :title="t('SIDEBAR.MOVE_DOWN')"
            :aria-label="t('SIDEBAR.MOVE_DOWN')"
            data-test="menu-order-down"
            @click="move(index, 1)"
          />
        </div>
      </template>
    </Draggable>
    <div class="flex items-center justify-between gap-2 px-1">
      <button
        type="button"
        class="text-xs underline text-n-slate-11"
        data-test="menu-order-reset"
        @click="emit('reset')"
      >
        {{ t('SIDEBAR.ORGANIZE_MENU_RESET') }}
      </button>
      <Button
        type="button"
        size="xs"
        :label="t('SIDEBAR.ORGANIZE_MENU_DONE')"
        data-test="menu-order-done"
        @click="emit('done')"
      />
    </div>
  </div>
</template>
