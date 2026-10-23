export const MAX_AUTOMATIONS = 10;
export const MAX_DUE_IN_HOURS = 2160;
export const MAX_MESSAGE_LENGTH = 2000;
export const MAX_ACTIVITY_TITLE_LENGTH = 255;
export const AI_INSTRUCTIONS_MAX_LENGTH = 500;
export const DESTINATIONS_KEY = 'crmAutomationDestinations';

export const STATUSES = ['open', 'won', 'lost'];
export const ACTIVITY_TYPES = ['task', 'call', 'meeting', 'follow_up'];
export const AI_STATES = ['ai', 'human'];

export const STATUS_LABEL_KEYS = {
  open: 'CRM.STATUS_OPEN',
  won: 'CRM.STATUS_WON',
  lost: 'CRM.STATUS_LOST',
};
export const ACTIVITY_LABEL_KEYS = {
  task: 'CRM.AUTOMATION_ACTIVITY_TYPE_TASK',
  call: 'CRM.AUTOMATION_ACTIVITY_TYPE_CALL',
  meeting: 'CRM.AUTOMATION_ACTIVITY_TYPE_MEETING',
  follow_up: 'CRM.AUTOMATION_ACTIVITY_TYPE_FOLLOW_UP',
};
export const AI_STATE_LABEL_KEYS = {
  ai: 'CRM.AUTOMATION_AI_STATE_AI',
  human: 'CRM.AUTOMATION_AI_STATE_HUMAN',
};
export const AI_STATE_DESCRIPTION_KEYS = {
  ai: 'CRM.AUTOMATION_AI_STATE_AI_DESC',
  human: 'CRM.AUTOMATION_AI_STATE_HUMAN_DESC',
};

export const TEMPLATE_VARIABLES = [
  { key: 'first_name', helpKey: 'CRM.AUTOMATION_VARIABLE_HELP.FIRST_NAME' },
  { key: 'contact_name', helpKey: 'CRM.AUTOMATION_VARIABLE_HELP.CONTACT_NAME' },
  { key: 'lead_name', helpKey: 'CRM.AUTOMATION_VARIABLE_HELP.LEAD_NAME' },
  { key: 'stage_name', helpKey: 'CRM.AUTOMATION_VARIABLE_HELP.STAGE_NAME' },
  {
    key: 'pipeline_name',
    helpKey: 'CRM.AUTOMATION_VARIABLE_HELP.PIPELINE_NAME',
  },
  { key: 'owner_name', helpKey: 'CRM.AUTOMATION_VARIABLE_HELP.OWNER_NAME' },
];

export const ACTION_TYPES = {
  set_status: {
    icon: 'i-lucide-flag',
    group: 'deal',
    labelKey: 'CRM.AUTOMATION_TYPE_SET_STATUS',
    descriptionKey: 'CRM.AUTOMATION_TYPE_SET_STATUS_DESC',
    defaults: kind => ({ status: kind === 'stage' ? 'won' : 'open' }),
  },
  assign_owner: {
    icon: 'i-lucide-user-round',
    group: 'deal',
    labelKey: 'CRM.AUTOMATION_TYPE_ASSIGN_OWNER',
    descriptionKey: 'CRM.AUTOMATION_TYPE_ASSIGN_OWNER_DESC',
    defaults: () => ({ user_id: null }),
  },
  create_activity: {
    icon: 'i-lucide-calendar-plus',
    group: 'deal',
    labelKey: 'CRM.AUTOMATION_TYPE_CREATE_ACTIVITY',
    descriptionKey: 'CRM.AUTOMATION_TYPE_CREATE_ACTIVITY_DESC',
    defaults: () => ({
      activity_type: 'follow_up',
      title: '',
      due_in_hours: 24,
    }),
  },
  move_stage: {
    icon: 'i-lucide-arrow-right-left',
    group: 'deal',
    labelKey: 'CRM.AUTOMATION_TYPE_MOVE_STAGE',
    descriptionKey: 'CRM.AUTOMATION_TYPE_MOVE_STAGE_DESC',
    defaults: () => ({ pipeline_id: null, stage_id: null }),
  },
  send_message: {
    icon: 'i-lucide-message-square',
    group: 'conversation',
    labelKey: 'CRM.AUTOMATION_TYPE_SEND_MESSAGE',
    descriptionKey: 'CRM.AUTOMATION_TYPE_SEND_MESSAGE_DESC',
    defaults: () => ({ content: '' }),
  },
  add_label: {
    icon: 'i-lucide-tag',
    group: 'conversation',
    labelKey: 'CRM.AUTOMATION_TYPE_ADD_LABEL',
    descriptionKey: 'CRM.AUTOMATION_TYPE_ADD_LABEL_DESC',
    defaults: () => ({ label: '' }),
  },
  set_ai_state: {
    icon: 'i-lucide-bot',
    group: 'conversation',
    labelKey: 'CRM.AUTOMATION_TYPE_SET_AI_STATE',
    descriptionKey: 'CRM.AUTOMATION_TYPE_SET_AI_STATE_DESC',
    defaults: () => ({ state: 'human' }),
  },
  send_webhook: {
    icon: 'i-lucide-webhook',
    group: 'integration',
    labelKey: 'CRM.AUTOMATION_TYPE_SEND_WEBHOOK',
    descriptionKey: 'CRM.AUTOMATION_TYPE_SEND_WEBHOOK_DESC',
    defaults: () => ({ url: '' }),
  },
};

export const ACTION_GROUPS = [
  {
    id: 'deal',
    labelKey: 'CRM.AUTOMATION_GROUP_DEAL',
    types: ['move_stage', 'assign_owner', 'create_activity', 'set_status'],
  },
  {
    id: 'conversation',
    labelKey: 'CRM.AUTOMATION_GROUP_CONVERSATION',
    types: ['send_message', 'add_label', 'set_ai_state'],
  },
  {
    id: 'integration',
    labelKey: 'CRM.AUTOMATION_GROUP_INTEGRATION',
    types: ['send_webhook'],
  },
];

export const TRIGGERS = {
  stage: {
    icon: 'i-lucide-log-in',
    badgeClass: 'bg-n-blue-3 text-n-blue-11',
    textClass: 'text-n-blue-11',
    titleKey: 'CRM.TRIGGER_STAGE_TITLE',
    helpKey: 'CRM.TRIGGER_STAGE_HELP',
    emptyKey: 'CRM.AUTOMATION_EMPTY_STAGE',
    webhookEvent: 'crm_deal_stage_entered',
  },
  won: {
    icon: 'i-lucide-trophy',
    badgeClass: 'bg-n-teal-3 text-n-teal-11',
    textClass: 'text-n-teal-11',
    titleKey: 'CRM.TRIGGER_WON_TITLE',
    helpKey: 'CRM.TRIGGER_WON_HELP',
    emptyKey: 'CRM.AUTOMATION_EMPTY_WON',
    railKey: 'CRM.AUTOMATION_RAIL_WON',
    descriptionKey: 'CRM.CLOSING_WON_DESC',
    webhookEvent: 'crm_deal_won',
  },
  lost: {
    icon: 'i-lucide-circle-x',
    badgeClass: 'bg-n-ruby-3 text-n-ruby-11',
    textClass: 'text-n-ruby-11',
    titleKey: 'CRM.TRIGGER_LOST_TITLE',
    helpKey: 'CRM.TRIGGER_LOST_HELP',
    emptyKey: 'CRM.AUTOMATION_EMPTY_LOST',
    railKey: 'CRM.AUTOMATION_RAIL_LOST',
    descriptionKey: 'CRM.CLOSING_LOST_DESC',
    webhookEvent: 'crm_deal_lost',
  },
};

export const createAction = (type, kind = 'stage') => ({
  key: crypto.randomUUID(),
  type,
  ...ACTION_TYPES[type].defaults(kind),
});

export const cloneAutomations = actions =>
  (actions || []).map(action => ({ ...action, key: crypto.randomUUID() }));

export const serializeAutomations = actions =>
  (actions || []).map(({ key, ...action }) => action);

// Only RFC 3986 characters: the backend parses the URL with URI.parse and rejects anything else.
const WEBHOOK_URL = /^https?:\/\/[\w.~:/?#[\]@!$&'()*+,;=%-]+$/;
const ERROR_PREFIX = 'CRM.AUTOMATION_ERRORS.';
const isBlank = value => !value?.trim();

export const getActionErrors = (action, { destinations = null } = {}) => {
  const errors = {};
  const fail = (field, code) => {
    errors[field] = `${ERROR_PREFIX}${code}`;
  };

  switch (action.type) {
    case 'set_status':
      if (!STATUSES.includes(action.status)) fail('status', 'OPTION_REQUIRED');
      break;
    case 'assign_owner':
      if (!Number.isInteger(action.user_id)) fail('user_id', 'OWNER_REQUIRED');
      break;
    case 'create_activity':
      if (!ACTIVITY_TYPES.includes(action.activity_type)) {
        fail('activity_type', 'OPTION_REQUIRED');
      }
      if (isBlank(action.title)) fail('title', 'ACTIVITY_TITLE_REQUIRED');
      else if (action.title.trim().length > MAX_ACTIVITY_TITLE_LENGTH) {
        fail('title', 'ACTIVITY_TITLE_TOO_LONG');
      }
      if (
        !Number.isInteger(action.due_in_hours) ||
        action.due_in_hours < 1 ||
        action.due_in_hours > MAX_DUE_IN_HOURS
      ) {
        fail('due_in_hours', 'DUE_INVALID');
      }
      break;
    case 'add_label':
      if (isBlank(action.label)) fail('label', 'LABEL_REQUIRED');
      break;
    case 'set_ai_state':
      if (!AI_STATES.includes(action.state)) fail('state', 'OPTION_REQUIRED');
      break;
    case 'send_message':
      if (isBlank(action.content)) fail('content', 'MESSAGE_REQUIRED');
      else if (action.content.length > MAX_MESSAGE_LENGTH) {
        fail('content', 'MESSAGE_TOO_LONG');
      }
      break;
    case 'move_stage':
      if (!Number.isInteger(action.pipeline_id)) {
        fail('pipeline_id', 'PIPELINE_REQUIRED');
      } else if (!Number.isInteger(action.stage_id)) {
        fail('stage_id', 'STAGE_REQUIRED');
      } else if (
        destinations &&
        !destinations.some(
          pipeline =>
            pipeline.id === action.pipeline_id &&
            pipeline.stages.some(stage => stage.id === action.stage_id)
        )
      ) {
        fail('stage_id', 'STAGE_UNAVAILABLE');
      }
      break;
    case 'send_webhook':
      if (isBlank(action.url)) fail('url', 'URL_REQUIRED');
      else if (!WEBHOOK_URL.test(action.url)) fail('url', 'URL_INVALID');
      break;
    default:
      fail('type', 'OPTION_REQUIRED');
  }
  return errors;
};

export const isAutomationValid = (action, context) =>
  !Object.keys(getActionErrors(action, context)).length;

export const getActionSummary = (
  action,
  { t, agents, destinations = null }
) => {
  const unset = t('CRM.AUTOMATION_SUMMARY_UNSET');
  if (!isAutomationValid(action)) return unset;

  switch (action.type) {
    case 'set_status':
      return t('CRM.AUTOMATION_SUMMARY_STATUS', {
        status: t(STATUS_LABEL_KEYS[action.status]),
      });
    case 'assign_owner': {
      const agent = agents.find(({ id }) => id === action.user_id);
      return agent
        ? t('CRM.AUTOMATION_SUMMARY_OWNER', { name: agent.name })
        : unset;
    }
    case 'create_activity':
      return t('CRM.AUTOMATION_SUMMARY_ACTIVITY', {
        type: t(ACTIVITY_LABEL_KEYS[action.activity_type]),
        title: action.title.trim(),
        hours: action.due_in_hours,
      });
    case 'add_label':
      return t('CRM.AUTOMATION_SUMMARY_LABEL', { label: action.label });
    case 'set_ai_state':
      return t(AI_STATE_LABEL_KEYS[action.state]);
    case 'send_message':
      return action.content.trim().replace(/\s+/g, ' ').slice(0, 200);
    case 'move_stage': {
      const pipeline = (destinations ?? []).find(
        ({ id }) => id === action.pipeline_id
      );
      const stage = pipeline?.stages.find(({ id }) => id === action.stage_id);
      return stage ? `${pipeline.name} › ${stage.name}` : unset;
    }
    default:
      return action.url;
  }
};

export const getWebhookSample = kind => ({
  event: TRIGGERS[kind].webhookEvent,
  account_id: 1,
  lead: {
    id: 42,
    name: 'Maria Silva',
    value: 2500,
    status: 'open',
    description: null,
    created_at: '2025-01-15T12:00:00Z',
    updated_at: '2025-01-15T12:30:00Z',
    pipeline: { id: 1, name: 'Comercial' },
    stage: { id: 10, name: 'Proposta', probability: 60 },
    owner: { id: 7, name: 'João', email: 'joao@example.com' },
    custom_fields: { origem: 'Instagram' },
  },
  contact: {
    id: 30,
    name: 'Maria Silva',
    phone_number: '+5511999999999',
    email: 'maria@example.com',
    identifier: null,
    custom_attributes: {},
    labels: ['vip'],
  },
  conversation: { id: 128, status: 'open', labels: ['vip'] },
});
