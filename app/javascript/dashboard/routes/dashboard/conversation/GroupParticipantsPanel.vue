<script setup>
import GroupManagementPanel from './GroupManagementPanel.vue';

defineProps({ conversationId: { type: [Number, String], required: true } });
</script>

<template>
  <GroupManagementPanel
    :key="conversationId"
    :conversation-id="conversationId"
  />
</template>
