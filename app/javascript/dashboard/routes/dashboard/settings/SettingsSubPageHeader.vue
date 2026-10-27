<script>
export default {
  props: {
    headerTitle: { type: String, default: '' },
    headerContent: { type: String, default: '' },
  },
};
</script>

<template>
  <div class="mb-4 flex w-full flex-col items-start gap-1.5">
    <h2 class="text-heading-1 text-n-slate-12 break-words">
      {{ headerTitle }}
    </h2>
    <p
      v-dompurify-html="headerContent"
      class="text-body-main w-full text-n-slate-11"
    />
  </div>
</template>
