import { computed, inject, onMounted, provide, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { customFieldsAPI, pipelinesAPI, segmentsAPI } from 'dashboard/api/crm';
import { workflowLostReasonsAPI } from 'dashboard/api/automationWorkflows';
import { buildLookups } from './lookups';

const LOOKUPS_KEY = Symbol('workflowLookups');
const STORE_LOADERS = [
  'inboxes/get',
  'agents/get',
  'teams/get',
  'labels/get',
  'attributes/get',
];

// A lookup that fails to load (e.g. the CRM is not available) just stays empty.
const loadList = async request => {
  try {
    const { data } = await request();
    return Array.isArray(data) ? data : [];
  } catch {
    return [];
  }
};

export const provideWorkflowLookups = () => {
  const store = useStore();
  const { t } = useI18n();
  const pipelines = ref([]);
  const segments = ref([]);
  const lostReasons = ref([]);
  const dealFields = ref([]);
  const isLoaded = ref(false);

  const getters = store.getters;
  const lookups = computed(() =>
    buildLookups(
      {
        agents: getters['agents/getAgents'],
        teams: getters['teams/getTeams'],
        inboxes: getters['inboxes/getInboxes'],
        labels: getters['labels/getLabels'],
        contactAttributes:
          getters['attributes/getAttributesByModel']('contact_attribute'),
        pipelines: pipelines.value,
        segments: segments.value,
        lostReasons: lostReasons.value,
        dealFields: dealFields.value,
      },
      t
    )
  );

  const load = async () => {
    STORE_LOADERS.forEach(action => store.dispatch(action));
    [pipelines.value, segments.value, lostReasons.value, dealFields.value] =
      await Promise.all([
        loadList(() => pipelinesAPI.get()),
        loadList(() => segmentsAPI.get()),
        loadList(() => workflowLostReasonsAPI.get()),
        loadList(() => customFieldsAPI.get()),
      ]);
    isLoaded.value = true;
  };

  onMounted(load);
  const api = { lookups, lostReasons, isLoaded, reload: load };
  provide(LOOKUPS_KEY, api);
  return api;
};

export const useWorkflowLookups = () => inject(LOOKUPS_KEY);
