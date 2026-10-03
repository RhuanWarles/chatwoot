<script setup>
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import SearchResultSection from './SearchResultSection.vue';
import { brlFormatter } from 'dashboard/routes/dashboard/crm/components/currencyHelpers';
import { formatContactPhone } from 'dashboard/routes/dashboard/crm/components/contactHelpers';

defineProps({
  deals: { type: Array, default: () => [] },
  query: { type: String, default: '' },
  isFetching: { type: Boolean, default: false },
  showTitle: { type: Boolean, default: true },
});
const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');
const statusLabel = status => {
  if (status === 'won') return t('CRM.STATUS_WON');
  if (status === 'lost') return t('CRM.STATUS_LOST');
  return t('CRM.FILTER_OPEN');
};
</script>

<template>
  <SearchResultSection
    :title="t('SEARCH.SECTION.DEALS')"
    :empty="!deals.length"
    :query="query"
    :show-title="showTitle"
    :is-fetching="isFetching"
  >
    <RouterLink
      v-for="deal in deals"
      :key="deal.id"
      :to="{ name: 'crm_deal_details', params: { accountId, dealId: deal.id } }"
      class="block min-w-0 mb-2 rounded-xl focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-n-brand"
    >
      <CardLayout
        layout="row"
        class="[&>div]:px-4 [&>div]:py-3 hover:bg-n-slate-2 dark:hover:bg-n-solid-3"
      >
        <div class="flex flex-col gap-1 w-full min-w-0">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <h5
              class="m-0 text-sm font-medium text-n-slate-12 [overflow-wrap:anywhere]"
            >
              {{ deal.name }}
            </h5>
            <span
              class="px-2 py-0.5 rounded-md text-xs"
              :class="
                deal.status === 'won'
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : deal.status === 'lost'
                    ? 'bg-n-ruby-3 text-n-ruby-11'
                    : 'bg-n-blue-3 text-n-blue-11'
              "
              >{{ statusLabel(deal.status) }}</span
            >
          </div>
          <p class="m-0 text-xs text-n-slate-11 [overflow-wrap:anywhere]">
            {{
              t('CRM.DEAL_SEARCH_CONTEXT', {
                pipeline: deal.pipeline.name,
                stage: deal.pipelineStage.name,
              })
            }}
          </p>
          <p
            v-if="deal.contact?.name"
            class="m-0 text-sm text-n-slate-12 [overflow-wrap:anywhere]"
          >
            {{ t('CRM.DEAL_SEARCH_CONTACT', { name: deal.contact.name }) }}
          </p>
          <div
            class="flex flex-wrap gap-x-3 text-xs text-n-slate-11 [overflow-wrap:anywhere]"
          >
            <span v-if="deal.contact?.phoneNumber">{{
              formatContactPhone(deal.contact.phoneNumber)
            }}</span>
            <span v-if="deal.contact?.email">{{ deal.contact.email }}</span>
            <span v-if="deal.contact?.companyName">{{
              deal.contact.companyName
            }}</span>
          </div>
          <p
            v-if="deal.value != null && deal.value !== ''"
            class="m-0 text-sm font-medium text-n-slate-12"
          >
            {{ brlFormatter.format(Number(deal.value)) }}
          </p>
        </div>
      </CardLayout>
    </RouterLink>
  </SearchResultSection>
</template>
