<script setup>
import { ref } from 'vue';

const props = defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  defaultOpen: {
    type: Boolean,
    default: true,
  },
  // Render the content only once the section is opened for the first time.
  lazy: {
    type: Boolean,
    default: false,
  },
});

const open = ref(props.defaultOpen);
const rendered = ref(props.defaultOpen || !props.lazy);

const toggle = () => {
  open.value = !open.value;
  if (open.value) rendered.value = true;
};
</script>

<template>
  <section class="rounded-xl bg-n-solid-2">
    <button
      type="button"
      class="flex items-center justify-between w-full gap-3 p-5 text-start"
      :aria-expanded="open"
      @click="toggle"
    >
      <span class="min-w-0">
        <span class="block font-medium text-n-slate-12">{{ title }}</span>
        <span v-if="description" class="block mt-1 text-sm text-n-slate-11">{{
          description
        }}</span>
      </span>
      <span
        class="i-lucide-chevron-down size-4 shrink-0 text-n-slate-11 transition-transform"
        :class="{ 'rotate-180': open }"
        aria-hidden="true"
      />
    </button>
    <div v-if="rendered" v-show="open" class="flex flex-col gap-5 px-5 pb-5">
      <slot />
    </div>
  </section>
</template>
