<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';

const props = defineProps({
  fullHeight: {
    type: Boolean,
    default: false,
  },
  keepAlive: {
    type: Boolean,
    default: true,
  },
  wide: {
    type: Boolean,
    default: false,
  },
});

const route = useRoute();
const isFullHeight = computed(() => props.fullHeight || route.meta?.fullHeight);
const isWide = computed(() => props.wide || route.meta?.wide);

// Routes that manage filters/pagination via query params opt out of
// query-keyed remounts, else every filter change rebuilds the page.
const routeKey = computed(() =>
  route.meta.reuseOnQueryChange ? route.path : route.fullPath
);
</script>

<template>
  <div
    class="flex flex-col w-full h-full m-0 pt-4 px-6 bg-n-surface-1"
    :class="isFullHeight ? 'min-h-0 overflow-hidden pb-4' : 'overflow-auto pb-8'"
  >
    <div
      class="flex items-start w-full mx-auto"
      :class="[
        isWide ? 'max-w-[120rem]' : 'max-w-5xl',
        { 'flex-1 min-h-0 overflow-hidden': isFullHeight },
      ]"
    >
      <router-view v-slot="{ Component }">
        <keep-alive v-if="props.keepAlive">
          <component :is="Component" :key="routeKey" />
        </keep-alive>
        <component :is="Component" v-else :key="routeKey" />
      </router-view>
    </div>
  </div>
</template>
