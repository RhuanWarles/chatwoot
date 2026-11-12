<script setup>
import { computed, inject } from 'vue';

const props = defineProps({
  index: {
    type: Number,
    default: 0,
  },
  name: {
    type: String,
    required: true,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  count: {
    type: Number,
    default: 0,
  },
  showBadge: {
    type: Boolean,
    default: true,
  },
  isCompact: {
    type: Boolean,
    default: false,
  },
  pill: {
    type: Boolean,
    default: false,
  },
});

const activeIndex = inject('activeIndex');
const updateActiveIndex = inject('updateActiveIndex');

const active = computed(() => props.index === activeIndex.value);
const getItemCount = computed(() => props.count);

const onTabClick = event => {
  event.preventDefault();
  if (!props.disabled) {
    updateActiveIndex(props.index);
  }
};
</script>

<template>
  <li
    class="my-0 hover:text-n-slate-12"
    :class="
      pill
        ? 'flex-auto min-w-0 mx-0'
        : 'flex-shrink-0 mx-2 ltr:first:ml-0 rtl:first:mr-0 ltr:last:mr-0 rtl:last:ml-0'
    "
  >
    <a
      class="flex items-center flex-row select-none cursor-pointer relative"
      :class="[
        pill
          ? 'justify-center gap-1 min-w-0 px-1 py-1.5 rounded-lg whitespace-nowrap text-[0.8125rem] font-medium leading-5 transition-all duration-200'
          : 'text-button after:absolute after:bottom-px after:left-0 after:right-0 after:h-[2px] after:rounded-full after:transition-all after:duration-200',
        pill && active
          ? 'bg-n-surface-1 dark:bg-n-solid-3 text-n-slate-12 shadow-sm outline outline-1 outline-n-weak'
          : '',
        !pill && active
          ? 'text-n-blue-11 after:bg-n-brand after:opacity-100'
          : '',
        !pill && !active
          ? 'text-n-slate-11 after:bg-transparent after:opacity-0'
          : '',
        pill && !active ? 'text-n-slate-11' : '',
        !pill && isCompact ? 'py-2.5' : '',
        !pill && !isCompact ? '!text-base py-3' : '',
      ]"
      @click="onTabClick"
    >
      <span :class="pill ? 'truncate' : ''">{{ name }}</span>
      <div
        v-if="showBadge && (!pill || getItemCount > 0)"
        class="rounded-full flex shrink-0 items-center justify-center font-medium my-0 py-0"
        :class="[
          pill
            ? 'h-[1.125rem] min-w-[1.125rem] px-1 text-[0.6875rem]'
            : 'h-5 text-xs ltr:ml-1 rtl:mr-1 px-1.5 min-w-[20px]',
          active
            ? 'bg-n-blue-3 text-n-blue-11'
            : 'bg-n-alpha-1 text-n-slate-10',
        ]"
      >
        <span>
          {{ getItemCount }}
        </span>
      </div>
    </a>
  </li>
</template>
