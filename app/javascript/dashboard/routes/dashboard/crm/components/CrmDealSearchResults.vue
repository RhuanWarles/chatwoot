<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { brlFormatter } from './currencyHelpers';
import { formatContactPhone } from './contactHelpers';

const props = defineProps({
  deals: { type: Array, default: () => [] },
  pipeline: { type: Object, default: null },
  query: { type: String, default: '' },
  loading: { type: Boolean, default: false },
  error: { type: String, default: '' },
});
const emit = defineEmits(['close']);
const { t } = useI18n();
const route = useRoute();
const panel = ref(null);
const DEAL_LIMIT = 8;
const RELATED_LIMIT = 5;
const suggestions = computed(() => props.deals.slice(0, DEAL_LIMIT));
const contacts = computed(() =>
  [
    ...new Map(
      props.deals
        .filter(deal => deal.contact)
        .map(deal => [deal.contact.id, deal.contact])
    ).values(),
  ].slice(0, RELATED_LIMIT)
);
const companies = computed(() =>
  [
    ...new Map(
      props.deals
        .filter(deal => deal.contact?.company?.id)
        .map(deal => [deal.contact.company.id, deal.contact.company])
    ).values(),
  ].slice(0, RELATED_LIMIT)
);
const navigateKeyboard = event => {
  if (!['ArrowDown', 'ArrowUp'].includes(event.key)) return;
  event.preventDefault();
  const items = [...panel.value.querySelectorAll('a, button:not(:disabled)')];
  if (!items.length) return;
  const index = items.indexOf(document.activeElement);
  const direction = event.key === 'ArrowDown' ? 1 : -1;
  const initial = direction === 1 ? 0 : items.length - 1;
  const next =
    index < 0 ? initial : (index + direction + items.length) % items.length;
  items[next].focus();
};
const focusFirst = () =>
  panel.value?.querySelector('a, button:not(:disabled)')?.focus();
defineExpose({ focusFirst });
</script>

<template>
  <div
    ref="panel"
    role="region"
    :aria-label="t('CRM.DEAL_SEARCH_RESULTS')"
    class="flex flex-col w-80 sm:w-96 max-h-96 overflow-y-auto p-3 gap-2 bg-n-solid-1 text-n-slate-12"
    @keydown="navigateKeyboard"
  >
    <h3 class="m-0 text-sm font-semibold">
      {{ t('CRM.DEAL_SEARCH_RESULTS') }}
    </h3>
    <p v-if="loading" role="status" class="m-0 text-sm text-n-slate-11">
      {{ t('CRM.DEAL_SEARCH_LOADING') }}
    </p>
    <p v-else-if="error" role="alert" class="m-0 text-sm text-n-ruby-11">
      {{ error }}
    </p>
    <p v-else-if="!deals.length" class="m-0 text-sm text-n-slate-11">
      {{ t('CRM.DEAL_SEARCH_EMPTY_QUERY', { query }) }}
    </p>
    <template v-else>
      <h4 class="mt-1 mb-0 text-xs font-medium text-n-slate-11">
        {{ t('CRM.DEALS_TITLE') }}
      </h4>
      <RouterLink
        v-for="deal in suggestions"
        :key="deal.id"
        :to="{
          name: 'crm_deal_details',
          params: { accountId: route.params.accountId, dealId: deal.id },
        }"
        class="flex flex-col gap-1 p-2 rounded-lg hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-n-brand"
        @click="emit('close')"
      >
        <span class="text-sm font-medium [overflow-wrap:anywhere]">{{
          deal.name
        }}</span>
        <span
          v-if="deal.contact?.name"
          class="text-xs text-n-slate-11 [overflow-wrap:anywhere]"
          >{{ t('CRM.DEAL_SEARCH_CONTACT', { name: deal.contact.name }) }}</span
        >
        <span class="text-xs text-n-slate-11 [overflow-wrap:anywhere]">{{
          t('CRM.DEAL_SEARCH_CONTEXT', {
            pipeline: pipeline?.name || '',
            stage:
              deal.pipeline_stage?.name ||
              pipeline?.stages.find(
                stage => stage.id === deal.pipeline_stage_id
              )?.name ||
              '',
          })
        }}</span>
        <span
          v-if="deal.value != null && deal.value !== ''"
          class="text-sm font-medium"
          >{{ brlFormatter.format(Number(deal.value)) }}</span
        >
        <span
          v-if="deal.status === 'won' || deal.status === 'lost'"
          class="self-start px-2 py-0.5 rounded-md text-xs"
          :class="
            deal.status === 'won'
              ? 'bg-n-teal-3 text-n-teal-11'
              : 'bg-n-ruby-3 text-n-ruby-11'
          "
          >{{
            deal.status === 'won' ? t('CRM.STATUS_WON') : t('CRM.STATUS_LOST')
          }}</span
        >
      </RouterLink>
      <Button
        v-if="deals.length > DEAL_LIMIT"
        size="sm"
        variant="ghost"
        :label="t('CRM.DEAL_SEARCH_VIEW_ALL')"
        @click="emit('close')"
      />
      <h4
        v-if="contacts.length"
        class="mt-2 mb-0 text-xs font-medium text-n-slate-11"
      >
        {{ t('CRM.DEAL_SEARCH_CONTACTS') }}
      </h4>
      <RouterLink
        v-for="contact in contacts"
        :key="contact.id"
        :to="{
          name: 'contacts_edit',
          params: { accountId: route.params.accountId, contactId: contact.id },
        }"
        class="flex items-start gap-2 p-2 rounded-lg hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-n-brand"
        @click="emit('close')"
      >
        <Avatar
          :name="contact.name || ''"
          :src="contact.thumbnail || ''"
          :size="24"
        />
        <span class="flex flex-col gap-1 min-w-0">
          <span class="text-sm font-medium [overflow-wrap:anywhere]">{{
            contact.name
          }}</span>
          <span
            v-if="contact.phone_number"
            class="text-xs text-n-slate-11 [overflow-wrap:anywhere]"
            >{{ formatContactPhone(contact.phone_number) }}</span
          >
          <span
            v-if="contact.email"
            class="text-xs text-n-slate-11 [overflow-wrap:anywhere]"
            >{{ contact.email }}</span
          >
        </span>
      </RouterLink>
      <h4
        v-if="companies.length"
        class="mt-2 mb-0 text-xs font-medium text-n-slate-11"
      >
        {{ t('CRM.DEAL_SEARCH_COMPANIES') }}
      </h4>
      <RouterLink
        v-for="company in companies"
        :key="company.id"
        :to="{
          name: 'companies_dashboard_show',
          params: { accountId: route.params.accountId, companyId: company.id },
        }"
        class="p-2 text-sm rounded-lg [overflow-wrap:anywhere] hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-n-brand"
        @click="emit('close')"
        >{{ company.name }}</RouterLink
      >
    </template>
  </div>
</template>
