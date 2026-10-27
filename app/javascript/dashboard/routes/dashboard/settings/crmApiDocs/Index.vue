<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();

const baseUrl = computed(
  () => `${window.location.origin}/api/v1/accounts/:account_id/crm`
);

const curlExample = computed(
  () =>
    `curl --request GET \\\n  --url ${baseUrl.value}/pipelines \\\n  --header 'api_access_token: SEU_TOKEN'`
);

const pipelineExample = `{
  "pipeline": {
    "name": "Vendas",
    "description": "Funil comercial",
    "active": true,
    "won_automations": [],
    "lost_automations": []
  }
}`;

const stageExample = `{
  "pipeline_stage": {
    "name": "Proposta enviada",
    "position": 1,
    "color": "#6366f1",
    "probability": 50,
    "ai_instructions": "Mover quando a proposta for enviada.",
    "automations": []
  }
}`;

const dealExample = `{
  "deal": {
    "name": "Lead do grupo WhatsApp",
    "pipeline_id": 1,
    "pipeline_stage_id": 2,
    "contact_id": 123,
    "owner_id": 45,
    "value": 1500,
    "status": "open",
    "description": "Origem: grupo WhatsApp"
  }
}`;

const activityExample = `{
  "activity": {
    "activity_type": "meeting",
    "title": "Reunião de descoberta",
    "description": "Entender o cenário do cliente.",
    "due_at": "2026-10-30T14:00:00-03:00",
    "owner_id": 45,
    "status": "pending",
    "duration_minutes": 30,
    "participants": ["cliente@example.com"],
    "create_calendar": false,
    "create_meet": false
  }
}`;

const responseExample = `{
  "id": 42,
  "name": "Lead do grupo WhatsApp",
  "status": "open",
  "value": 1500.0,
  "pipeline_id": 1,
  "pipeline_stage_id": 2,
  "contact": {
    "id": 123,
    "name": "Rhuan Warles"
  },
  "pipeline_stage": {
    "id": 2,
    "name": "Proposta enviada"
  }
}`;

const customFieldExample = `{
  "custom_field": {
    "name": "Origem do lead",
    "key": "origem_do_lead",
    "field_type": "select",
    "required": false,
    "active": true,
    "position": 0,
    "options": ["WhatsApp", "Indicação", "Site"]
  }
}`;

const automationExample = `[
  {
    "type": "set_status",
    "status": "won"
  },
  {
    "type": "send_webhook",
    "url": "https://example.com/crm/webhook"
  }
]`;

const sections = computed(() => {
  const endpoint = (method, path, descriptionKey) => ({
    method,
    path,
    // The endpoint catalogue is translated at render time with the active locale.
    // eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys
    description: t(descriptionKey),
  });

  return [
    {
      id: 'pipelines',
      title: t('CRM_API_DOCS.PIPELINES_TITLE'),
      description: t('CRM_API_DOCS.PIPELINES_DESCRIPTION'),
      endpoints: [
        endpoint('GET', '/pipelines', 'CRM_API_DOCS.LIST_PIPELINES'),
        endpoint('GET', '/pipelines/:id', 'CRM_API_DOCS.SHOW_PIPELINE'),
        endpoint('POST', '/pipelines', 'CRM_API_DOCS.CREATE_PIPELINE'),
        endpoint('PATCH', '/pipelines/:id', 'CRM_API_DOCS.UPDATE_PIPELINE'),
        endpoint('DELETE', '/pipelines/:id', 'CRM_API_DOCS.DELETE_PIPELINE'),
      ],
    },
    {
      id: 'stages',
      title: t('CRM_API_DOCS.STAGES_TITLE'),
      description: t('CRM_API_DOCS.STAGES_DESCRIPTION'),
      endpoints: [
        endpoint(
          'POST',
          '/pipelines/:pipeline_id/stages',
          'CRM_API_DOCS.CREATE_STAGE'
        ),
        endpoint(
          'PATCH',
          '/pipelines/:pipeline_id/stages/:id',
          'CRM_API_DOCS.UPDATE_STAGE'
        ),
        endpoint(
          'DELETE',
          '/pipelines/:pipeline_id/stages/:id',
          'CRM_API_DOCS.DELETE_STAGE'
        ),
        endpoint(
          'PATCH',
          '/pipelines/:pipeline_id/stages/reorder',
          'CRM_API_DOCS.REORDER_STAGES'
        ),
      ],
    },
    {
      id: 'deals',
      title: t('CRM_API_DOCS.DEALS_TITLE'),
      description: t('CRM_API_DOCS.DEALS_DESCRIPTION'),
      endpoints: [
        endpoint('GET', '/deals', 'CRM_API_DOCS.LIST_DEALS'),
        endpoint('GET', '/deals/:id', 'CRM_API_DOCS.SHOW_DEAL'),
        endpoint('POST', '/deals', 'CRM_API_DOCS.CREATE_DEAL'),
        endpoint('PATCH', '/deals/:id', 'CRM_API_DOCS.UPDATE_DEAL'),
        endpoint('DELETE', '/deals/:id', 'CRM_API_DOCS.DELETE_DEAL'),
      ],
    },
    {
      id: 'custom-fields',
      title: t('CRM_API_DOCS.CUSTOM_FIELDS_TITLE'),
      description: t('CRM_API_DOCS.CUSTOM_FIELDS_DESCRIPTION'),
      endpoints: [
        endpoint('GET', '/custom_fields', 'CRM_API_DOCS.LIST_CUSTOM_FIELDS'),
        endpoint('GET', '/custom_fields/:id', 'CRM_API_DOCS.SHOW_CUSTOM_FIELD'),
        endpoint('POST', '/custom_fields', 'CRM_API_DOCS.CREATE_CUSTOM_FIELD'),
        endpoint(
          'PATCH',
          '/custom_fields/:id',
          'CRM_API_DOCS.UPDATE_CUSTOM_FIELD'
        ),
        endpoint(
          'DELETE',
          '/custom_fields/:id',
          'CRM_API_DOCS.DELETE_CUSTOM_FIELD'
        ),
        endpoint(
          'GET',
          '/deals/:deal_id/custom_fields',
          'CRM_API_DOCS.SHOW_DEAL_VALUES'
        ),
        endpoint(
          'PATCH',
          '/deals/:deal_id/custom_fields',
          'CRM_API_DOCS.UPDATE_DEAL_VALUES'
        ),
      ],
    },
    {
      id: 'activities',
      title: t('CRM_API_DOCS.ACTIVITIES_TITLE'),
      description: t('CRM_API_DOCS.ACTIVITIES_DESCRIPTION'),
      endpoints: [
        endpoint(
          'GET',
          '/deals/:deal_id/activities',
          'CRM_API_DOCS.LIST_ACTIVITIES'
        ),
        endpoint(
          'POST',
          '/deals/:deal_id/activities',
          'CRM_API_DOCS.CREATE_ACTIVITY'
        ),
        endpoint(
          'PATCH',
          '/deals/:deal_id/activities/:id',
          'CRM_API_DOCS.UPDATE_ACTIVITY'
        ),
        endpoint(
          'POST',
          '/deals/:deal_id/activities/:id/retry_sync',
          'CRM_API_DOCS.RETRY_ACTIVITY'
        ),
      ],
    },
    {
      id: 'events',
      title: t('CRM_API_DOCS.EVENTS_TITLE'),
      description: t('CRM_API_DOCS.EVENTS_DESCRIPTION'),
      endpoints: [
        endpoint('GET', '/deals/:deal_id/events', 'CRM_API_DOCS.LIST_EVENTS'),
        endpoint('POST', '/deals/:deal_id/events', 'CRM_API_DOCS.CREATE_NOTE'),
        endpoint(
          'PATCH',
          '/deals/:deal_id/events/:id',
          'CRM_API_DOCS.UPDATE_NOTE'
        ),
        endpoint(
          'DELETE',
          '/deals/:deal_id/events/:id',
          'CRM_API_DOCS.DELETE_NOTE'
        ),
      ],
    },
    {
      id: 'calendar',
      title: t('CRM_API_DOCS.CALENDAR_TITLE'),
      description: t('CRM_API_DOCS.CALENDAR_DESCRIPTION'),
      endpoints: [
        endpoint('GET', '/google_calendar', 'CRM_API_DOCS.SHOW_CALENDAR'),
        endpoint('POST', '/google_calendar', 'CRM_API_DOCS.CONNECT_CALENDAR'),
        endpoint(
          'DELETE',
          '/google_calendar',
          'CRM_API_DOCS.DISCONNECT_CALENDAR'
        ),
      ],
    },
  ];
});

const filters = computed(() => [
  {
    path: 'GET /deals?pipeline_id=1',
    description: t('CRM_API_DOCS.FILTER_PIPELINE'),
    separator: t('CRM_API_DOCS.FILTER_SEPARATOR'),
  },
  {
    path: 'GET /deals?contact_id=123',
    description: t('CRM_API_DOCS.FILTER_CONTACT'),
    separator: t('CRM_API_DOCS.FILTER_SEPARATOR'),
  },
  {
    path: 'GET /deals?q=proposta',
    description: t('CRM_API_DOCS.FILTER_SEARCH'),
    separator: t('CRM_API_DOCS.FILTER_SEPARATOR'),
  },
  {
    path: 'GET /deals/:deal_id/events?page=2',
    description: t('CRM_API_DOCS.FILTER_EVENTS_PAGE'),
    separator: t('CRM_API_DOCS.FILTER_SEPARATOR'),
  },
]);

const copy = async value => {
  await copyTextToClipboard(value);
  useAlert(t('CRM_API_DOCS.COPY_SUCCESS'));
};
</script>

<template>
  <main class="flex flex-col w-full min-w-0 gap-6 pb-10">
    <BaseSettingsHeader
      :title="t('CRM_API_DOCS.TITLE')"
      :description="t('CRM_API_DOCS.DESCRIPTION')"
    />

    <section class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_18rem]">
      <div
        class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
      >
        <h2 class="mb-2 text-base font-semibold text-n-slate-12">
          {{ t('CRM_API_DOCS.BASE_URL_TITLE') }}
        </h2>
        <p class="mb-3 text-sm text-n-slate-11">
          {{ t('CRM_API_DOCS.BASE_URL_DESCRIPTION') }}
        </p>
        <div class="flex items-start gap-2">
          <div
            class="flex-1 p-3 overflow-auto text-xs rounded-lg bg-n-alpha-2 text-n-slate-12"
          >
            <code>{{ baseUrl }}</code>
          </div>
          <Button
            ghost
            slate
            sm
            icon="i-lucide-copy"
            :aria-label="t('CRM_API_DOCS.COPY')"
            @click="copy(baseUrl)"
          />
        </div>
      </div>

      <nav
        class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
      >
        <h2 class="mb-3 text-base font-semibold text-n-slate-12">
          {{ t('CRM_API_DOCS.ON_THIS_PAGE') }}
        </h2>
        <ul class="space-y-2 text-sm">
          <li v-for="section in sections" :key="section.id">
            <a :href="`#${section.id}`" class="text-n-blue-11 hover:underline">
              {{ section.title }}
            </a>
          </li>
        </ul>
      </nav>
    </section>

    <section
      class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
    >
      <h2 class="mb-2 text-base font-semibold text-n-slate-12">
        {{ t('CRM_API_DOCS.AUTH_TITLE') }}
      </h2>
      <p class="mb-3 text-sm text-n-slate-11">
        {{ t('CRM_API_DOCS.AUTH_DESCRIPTION') }}
      </p>
      <div class="flex items-start gap-2">
        <pre
          class="flex-1 p-3 overflow-auto text-xs rounded-lg bg-n-alpha-2 text-n-slate-12"
        ><code>{{ curlExample }}</code></pre>
        <Button
          ghost
          slate
          sm
          icon="i-lucide-copy"
          :aria-label="t('CRM_API_DOCS.COPY')"
          @click="copy(curlExample)"
        />
      </div>
      <p class="mt-3 text-xs text-n-slate-11">
        {{ t('CRM_API_DOCS.AUTH_WARNING') }}
      </p>
    </section>

    <section
      v-for="section in sections"
      :id="section.id"
      :key="section.id"
      class="p-5 rounded-xl bg-n-solid-2 scroll-mt-6"
    >
      <h2 class="mb-1 text-lg font-semibold text-n-slate-12">
        {{ section.title }}
      </h2>
      <p class="mb-4 text-sm text-n-slate-11">
        {{ section.description }}
      </p>
      <div class="overflow-hidden border rounded-lg border-n-weak">
        <div
          v-for="endpoint in section.endpoints"
          :key="`${endpoint.method}-${endpoint.path}`"
          class="flex flex-wrap items-baseline gap-3 px-4 py-3 border-b border-n-weak last:border-b-0"
        >
          <span class="w-16 text-xs font-semibold text-n-teal-11">
            {{ endpoint.method }}
          </span>
          <code class="text-xs text-n-slate-12">{{ endpoint.path }}</code>
          <span class="text-sm text-n-slate-11">{{
            endpoint.description
          }}</span>
        </div>
      </div>
    </section>

    <section class="grid gap-4 lg:grid-cols-2">
      <div
        class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
      >
        <h2 class="mb-2 text-base font-semibold text-n-slate-12">
          {{ t('CRM_API_DOCS.PIPELINE_BODY_TITLE') }}
        </h2>
        <pre
          class="p-3 overflow-auto text-xs rounded-lg bg-n-alpha-2 text-n-slate-12"
        ><code>{{ pipelineExample }}</code></pre>
        <p class="mt-3 text-xs text-n-slate-11">
          {{ t('CRM_API_DOCS.PIPELINE_BODY_HELP') }}
        </p>
      </div>
      <div
        class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
      >
        <h2 class="mb-2 text-base font-semibold text-n-slate-12">
          {{ t('CRM_API_DOCS.STAGE_BODY_TITLE') }}
        </h2>
        <pre
          class="p-3 overflow-auto text-xs rounded-lg bg-n-alpha-2 text-n-slate-12"
        ><code>{{ stageExample }}</code></pre>
        <p class="mt-3 text-xs text-n-slate-11">
          {{ t('CRM_API_DOCS.STAGE_BODY_HELP') }}
        </p>
      </div>
    </section>

    <section class="grid gap-4 lg:grid-cols-2">
      <div
        class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
      >
        <h2 class="mb-2 text-base font-semibold text-n-slate-12">
          {{ t('CRM_API_DOCS.RESPONSE_TITLE') }}
        </h2>
        <pre
          class="p-3 overflow-auto text-xs rounded-lg bg-n-alpha-2 text-n-slate-12"
        ><code>{{ responseExample }}</code></pre>
        <p class="mt-3 text-xs text-n-slate-11">
          {{ t('CRM_API_DOCS.RESPONSE_HELP') }}
        </p>
      </div>
      <div
        class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
      >
        <h2 class="mb-2 text-base font-semibold text-n-slate-12">
          {{ t('CRM_API_DOCS.FILTERS_TITLE') }}
        </h2>
        <ul class="space-y-2 text-sm list-disc ps-5 text-n-slate-11">
          <li v-for="filter in filters" :key="filter.path">
            <code>{{ filter.path }}</code>
            {{ filter.separator }}
            {{ filter.description }}
          </li>
        </ul>
      </div>
    </section>

    <section class="grid gap-4 lg:grid-cols-2">
      <div
        class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
      >
        <h2 class="mb-2 text-base font-semibold text-n-slate-12">
          {{ t('CRM_API_DOCS.DEAL_BODY_TITLE') }}
        </h2>
        <pre
          class="p-3 overflow-auto text-xs rounded-lg bg-n-alpha-2 text-n-slate-12"
        ><code>{{ dealExample }}</code></pre>
        <p class="mt-3 text-xs text-n-slate-11">
          {{ t('CRM_API_DOCS.DEAL_BODY_HELP') }}
        </p>
      </div>
      <div
        class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
      >
        <h2 class="mb-2 text-base font-semibold text-n-slate-12">
          {{ t('CRM_API_DOCS.ACTIVITY_BODY_TITLE') }}
        </h2>
        <pre
          class="p-3 overflow-auto text-xs rounded-lg bg-n-alpha-2 text-n-slate-12"
        ><code>{{ activityExample }}</code></pre>
        <p class="mt-3 text-xs text-n-slate-11">
          {{ t('CRM_API_DOCS.ACTIVITY_BODY_HELP') }}
        </p>
      </div>
    </section>

    <section class="grid gap-4 lg:grid-cols-2">
      <div
        class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
      >
        <h2 class="mb-2 text-base font-semibold text-n-slate-12">
          {{ t('CRM_API_DOCS.CUSTOM_FIELD_BODY_TITLE') }}
        </h2>
        <pre
          class="p-3 overflow-auto text-xs rounded-lg bg-n-alpha-2 text-n-slate-12"
        ><code>{{ customFieldExample }}</code></pre>
        <p class="mt-3 text-xs text-n-slate-11">
          {{ t('CRM_API_DOCS.CUSTOM_FIELD_BODY_HELP') }}
        </p>
      </div>
      <div
        class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
      >
        <h2 class="mb-2 text-base font-semibold text-n-slate-12">
          {{ t('CRM_API_DOCS.AUTOMATION_BODY_TITLE') }}
        </h2>
        <pre
          class="p-3 overflow-auto text-xs rounded-lg bg-n-alpha-2 text-n-slate-12"
        ><code>{{ automationExample }}</code></pre>
        <p class="mt-3 text-xs text-n-slate-11">
          {{ t('CRM_API_DOCS.AUTOMATION_BODY_HELP') }}
        </p>
      </div>
    </section>

    <section
      class="rounded-2xl bg-n-surface-1 p-5 shadow-sm outline outline-1 outline-n-container"
    >
      <h2 class="mb-2 text-base font-semibold text-n-slate-12">
        {{ t('CRM_API_DOCS.RULES_TITLE') }}
      </h2>
      <ul class="space-y-2 text-sm list-disc ps-5 text-n-slate-11">
        <li>{{ t('CRM_API_DOCS.RULE_ACCOUNT_SCOPE') }}</li>
        <li>{{ t('CRM_API_DOCS.RULE_PIPELINE_SCOPE') }}</li>
        <li>{{ t('CRM_API_DOCS.RULE_STAGE_SCOPE') }}</li>
        <li>{{ t('CRM_API_DOCS.RULE_ACTIVITY') }}</li>
        <li>{{ t('CRM_API_DOCS.RULE_NOTES') }}</li>
        <li>{{ t('CRM_API_DOCS.RULE_ERRORS') }}</li>
      </ul>
    </section>
  </main>
</template>
