<script setup>
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import GoogleCalendarConnection from './GoogleCalendarConnection.vue';
</script>

<template>
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        :title="$t('CRM.CALENDAR_TITLE')"
        :description="$t('CRM.CALENDAR_PERSONAL_CONNECTION')"
      />
    </template>
    <template #body><GoogleCalendarConnection /></template>
  </SettingsLayout>
</template>
