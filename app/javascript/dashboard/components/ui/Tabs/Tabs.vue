<script setup>
import { ref, useTemplateRef, provide, computed, watch, nextTick } from 'vue';
import { useElementSize, useMutationObserver } from '@vueuse/core';

const props = defineProps({
  index: {
    type: Number,
    default: 0,
  },
  border: {
    type: Boolean,
    default: true,
  },
  // Segmented control: the tabs share one rounded track and the active one is a raised pill.
  pill: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['change']);

const tabsContainer = useTemplateRef('tabsContainer');
const tabsList = useTemplateRef('tabsList');

const { width: containerWidth } = useElementSize(tabsContainer);
const { width: listWidth } = useElementSize(tabsList);

const hasScroll = ref(false);
const canScrollLeft = ref(false);
const canScrollRight = ref(false);

const activeIndex = computed({
  get: () => props.index,
  set: newValue => {
    emit('change', newValue);
  },
});

provide('activeIndex', activeIndex);
provide('updateActiveIndex', index => {
  activeIndex.value = index;
});

const updateScrollState = () => {
  const list = tabsList.value;
  if (!list) return;
  canScrollLeft.value = list.scrollLeft > 1;
  canScrollRight.value =
    list.scrollLeft + list.clientWidth < list.scrollWidth - 1;
};

// Width the tabs need on their own (labels, gaps and track padding), whether or not the scroll arrows are showing.
const getNeededWidth = list => {
  const style = getComputedStyle(list);
  const gap = parseFloat(style.columnGap) || 0;
  const padding =
    (parseFloat(style.paddingLeft) || 0) +
    (parseFloat(style.paddingRight) || 0);
  const items = Array.from(list.children);
  const itemsWidth = items.reduce((sum, el) => sum + el.offsetWidth, 0);
  return itemsWidth + gap * Math.max(items.length - 1, 0) + padding;
};

const computeScrollWidth = () => {
  const container = tabsContainer.value;
  const list = tabsList.value;
  if (container && list) {
    if (props.pill) {
      // Compare with the full width, not with the list: once the arrows show up they take space and the list gets
      // narrower, so tabs that fit without the arrows would be reported as not fitting and the arrows would stay.
      const style = getComputedStyle(container);
      const available =
        container.clientWidth -
        (parseFloat(style.paddingLeft) || 0) -
        (parseFloat(style.paddingRight) || 0);
      hasScroll.value = getNeededWidth(list) > available + 1;
    } else {
      hasScroll.value = list.scrollWidth > list.clientWidth;
    }
    updateScrollState();
  }
};

const onScrollClick = direction => {
  if (tabsContainer.value && tabsList.value) {
    let scrollPosition = tabsList.value.scrollLeft;
    scrollPosition += direction === 'left' ? -100 : 100;
    tabsList.value.scrollTo({
      top: 0,
      left: scrollPosition,
      behavior: 'smooth',
    });
  }
};

// Watch for changes in element sizes with immediate execution
watch(
  [containerWidth, listWidth],
  () => {
    computeScrollWidth();
  },
  { immediate: true }
);

// The pill track always takes the full width, so its own size never changes when a tab grows (a count arrives, a
// label changes, a tab appears). Watch the content too, otherwise the scroll arrows would never show up.
useMutationObserver(tabsList, computeScrollWidth, {
  childList: true,
  subtree: true,
  characterData: true,
});

// The arrows change the width of the list, so read the scroll position again once the layout has settled.
watch(hasScroll, () => nextTick(updateScrollState));

// Keep the selected pill visible when it sits outside the visible part of the track.
watch(
  () => props.index,
  () => {
    if (!props.pill) return;
    nextTick(() => {
      const list = tabsList.value;
      const item = list?.children[props.index];
      if (!item) return;
      // First and last tabs go all the way to the edge so the track padding is not left half hidden.
      if (props.index === 0) {
        list.scrollTo({ left: 0, behavior: 'smooth' });
      } else if (props.index === list.children.length - 1) {
        list.scrollTo({ left: list.scrollWidth, behavior: 'smooth' });
      } else {
        item.scrollIntoView({
          inline: 'nearest',
          block: 'nearest',
          behavior: 'smooth',
        });
      }
    });
  }
);

const listClasses = computed(() => {
  if (props.pill) {
    return [
      'gap-1 p-1 rounded-xl bg-n-alpha-1',
      hasScroll.value ? 'overflow-hidden flex-1 min-w-0' : 'w-full',
    ];
  }
  return [
    'min-w-[6.25rem] py-0 px-4',
    hasScroll.value ? 'overflow-hidden py-0 px-1 max-w-[calc(100%-64px)]' : '',
  ];
});

const arrowClasses = computed(() =>
  props.pill
    ? 'shrink-0 size-8 rounded-full text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors disabled:opacity-30 disabled:cursor-default disabled:hover:bg-transparent disabled:hover:text-n-slate-11'
    : 'rounded-none h-auto min-w-8'
);
</script>

<template>
  <div
    ref="tabsContainer"
    class="flex"
    :class="[
      border && !pill && 'border-b border-b-n-weak',
      pill && 'items-center gap-1',
    ]"
  >
    <button
      v-if="hasScroll"
      type="button"
      class="items-center cursor-pointer flex justify-center"
      :class="arrowClasses"
      :disabled="pill && !canScrollLeft"
      @click="onScrollClick('left')"
    >
      <fluent-icon icon="chevron-left" :size="16" />
    </button>
    <ul
      ref="tabsList"
      class="border-r-0 border-l-0 border-t-0 flex list-none mb-0"
      :class="listClasses"
      @scroll.passive="updateScrollState"
    >
      <slot />
    </ul>
    <button
      v-if="hasScroll"
      type="button"
      class="items-center cursor-pointer flex justify-center"
      :class="arrowClasses"
      :disabled="pill && !canScrollRight"
      @click="onScrollClick('right')"
    >
      <fluent-icon icon="chevron-right" :size="16" />
    </button>
  </div>
</template>
