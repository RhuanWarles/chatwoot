<script setup>
import { onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';

defineProps({
  keepAlive: { type: Boolean, default: true },
});

const store = useStore();

onMounted(() => {
  store.dispatch('campaigns/get');
  store.dispatch('labels/get');
});
</script>

<template>
  <div
    class="flex h-full min-h-0 flex-1 flex-col justify-between overflow-auto bg-n-surface-1"
  >
    <router-view v-slot="{ Component }">
      <keep-alive v-if="keepAlive">
        <component :is="Component" />
      </keep-alive>
      <component :is="Component" v-else />
    </router-view>
  </div>
</template>
