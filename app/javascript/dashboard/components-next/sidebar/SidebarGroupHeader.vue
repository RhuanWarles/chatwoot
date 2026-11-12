<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store.js';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  to: { type: [Object, String], default: '' },
  label: { type: String, default: '' },
  icon: { type: [String, Object], default: '' },
  expandable: { type: Boolean, default: false },
  isExpanded: { type: Boolean, default: false },
  isActive: { type: Boolean, default: false },
  hasActiveChild: { type: Boolean, default: false },
  getterKeys: { type: Object, default: () => ({}) },
});

const emit = defineEmits(['toggle']);

// The items are shown while the group is expanded or the open screen is one of them.
const isOpen = computed(() => props.isExpanded || props.hasActiveChild);

const router = useRouter();
const showBadge = useMapGetter(props.getterKeys.badge);
const dynamicCount = useMapGetter(props.getterKeys.count);
const count = computed(() =>
  dynamicCount.value > 99 ? '99+' : dynamicCount.value
);

// A real link so Cmd/Ctrl-click opens it in a new tab; a plain click keeps
// the in-app toggle instead of following the href.
const href = computed(() => (props.to ? router.resolve(props.to).href : null));

const onClick = event => {
  if (event.metaKey || event.altKey || event.ctrlKey || event.shiftKey) return;
  event.preventDefault();
  emit('toggle');
};
</script>

<template>
  <component
    :is="to ? 'a' : 'div'"
    class="flex items-center gap-2 px-1.5 py-1 rounded-lg h-8 min-w-0 transition-all duration-200"
    role="button"
    :aria-expanded="expandable ? isOpen : undefined"
    draggable="false"
    :href="href"
    :title="label"
    :class="{
      'text-n-slate-12 bg-n-surface-1 dark:bg-n-alpha-2 outline outline-1 outline-n-weak shadow-sm font-medium':
        isActive && !hasActiveChild,
      'text-n-slate-12 font-medium': hasActiveChild,
      'text-n-slate-11 hover:bg-n-alpha-2': !isActive && !hasActiveChild,
    }"
    @click.stop="onClick"
  >
    <div v-if="icon" class="relative flex items-center gap-2">
      <Icon v-if="icon" :icon="icon" class="size-4" />
      <span
        v-if="showBadge"
        class="size-2 -top-px ltr:-right-px rtl:-left-px bg-n-brand absolute rounded-full border border-n-solid-2"
      />
    </div>
    <div
      class="flex items-center gap-1.5 flex-grow justify-between min-w-0 flex-1"
    >
      <span
        class="truncate"
        :class="{
          'text-body-main': !isActive,
          'font-medium text-sm': isActive || hasActiveChild,
        }"
      >
        {{ label }}
      </span>
      <span
        v-if="dynamicCount && !expandable"
        class="inline-grid h-5 min-w-5 place-items-center rounded-full bg-n-slate-4 px-1 text-xxs font-medium leading-3 text-n-slate-12 dark:bg-n-slate-5 flex-shrink-0"
      >
        {{ count }}
      </span>
    </div>
    <!-- Every group that holds items shows it, so a tab with something inside is told apart from a plain link.
         It points down when closed and turns up when open. -->
    <span
      v-if="expandable"
      class="i-lucide-chevron-down size-3.5 flex-shrink-0 transition-transform duration-200"
      :class="isOpen ? 'rotate-180' : ''"
      data-test="group-chevron"
      aria-hidden="true"
      @click.stop.prevent="emit('toggle')"
    />
  </component>
</template>
