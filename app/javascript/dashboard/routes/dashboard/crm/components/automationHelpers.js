export const MAX_AUTOMATIONS = 50;
export const MAX_DUE_IN_HOURS = 2160;
export const MAX_MESSAGE_LENGTH = 2000;
export const MAX_ACTIVITY_TITLE_LENGTH = 255;
export const MAX_RULE_VALUE_LENGTH = 255;
export const MAX_RANDOM_OWNERS = 100;
export const MAX_ROUTES = 50;
export const AI_INSTRUCTIONS_MAX_LENGTH = 500;
export const DESTINATIONS_KEY = 'crmAutomationDestinations';
export const CUSTOM_FIELDS_KEY = 'crmAutomationCustomFields';

const VALUELESS_OPERATORS = ['filled', 'empty'];
const ORDERED_OPERATORS = ['gt', 'lt'];
const OPERATORS_BY_FIELD_TYPE = {
  text: ['equals', 'not_equals', 'contains', 'filled', 'empty'],
  textarea: ['equals', 'not_equals', 'contains', 'filled', 'empty'],
  number: ['equals', 'not_equals', 'gt', 'lt', 'filled', 'empty'],
  currency: ['equals', 'not_equals', 'gt', 'lt', 'filled', 'empty'],
  date: ['equals', 'gt', 'lt', 'filled', 'empty'],
  datetime: ['gt', 'lt', 'filled', 'empty'],
  boolean: ['equals', 'filled', 'empty'],
  select: ['equals', 'not_equals', 'filled', 'empty'],
  multiselect: ['equals', 'filled', 'empty'],
};
export const OPERATOR_LABEL_KEYS = {
  equals: 'CRM.AUTOMATION_OPERATOR_EQUALS',
  not_equals: 'CRM.AUTOMATION_OPERATOR_NOT_EQUALS',
  contains: 'CRM.AUTOMATION_OPERATOR_CONTAINS',
  gt: 'CRM.AUTOMATION_OPERATOR_GT',
  lt: 'CRM.AUTOMATION_OPERATOR_LT',
  filled: 'CRM.AUTOMATION_OPERATOR_FILLED',
  empty: 'CRM.AUTOMATION_OPERATOR_EMPTY',
};

export const getFieldOperators = field =>
  OPERATORS_BY_FIELD_TYPE[field?.field_type] || OPERATORS_BY_FIELD_TYPE.text;
export const isValuelessOperator = operator =>
  VALUELESS_OPERATORS.includes(operator);
// On a multiselect field, "equals" means that the list has the option.
export const getOperatorLabelKey = (operator, field) =>
  operator === 'equals' && field?.field_type === 'multiselect'
    ? 'CRM.AUTOMATION_OPERATOR_INCLUDES'
    : OPERATOR_LABEL_KEYS[operator];

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

export const createRoute = () => ({
  key: crypto.randomUUID(),
  operator: 'equals',
  value: '',
  pipeline_id: null,
  stage_id: null,
});

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
  assign_random: {
    icon: 'i-lucide-shuffle',
    group: 'deal',
    labelKey: 'CRM.AUTOMATION_TYPE_ASSIGN_RANDOM',
    descriptionKey: 'CRM.AUTOMATION_TYPE_ASSIGN_RANDOM_DESC',
    defaults: () => ({ user_ids: [] }),
  },
  route_by_field: {
    icon: 'i-lucide-git-branch',
    group: 'deal',
    labelKey: 'CRM.AUTOMATION_TYPE_ROUTE_BY_FIELD',
    descriptionKey: 'CRM.AUTOMATION_TYPE_ROUTE_BY_FIELD_DESC',
    defaults: () => ({
      custom_field_id: null,
      routes: [createRoute()],
      fallback: null,
    }),
  },
  set_field: {
    icon: 'i-lucide-pencil-line',
    group: 'deal',
    labelKey: 'CRM.AUTOMATION_TYPE_SET_FIELD',
    descriptionKey: 'CRM.AUTOMATION_TYPE_SET_FIELD_DESC',
    defaults: () => ({ custom_field_id: null, value: '' }),
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
    types: [
      'move_stage',
      'route_by_field',
      'assign_owner',
      'assign_random',
      'set_field',
      'create_activity',
      'set_status',
    ],
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
  field: {
    icon: 'i-lucide-text-cursor-input',
    badgeClass: 'bg-n-amber-3 text-n-amber-11',
    textClass: 'text-n-amber-11',
    titleKey: 'CRM.TRIGGER_FIELD_TITLE',
    helpKey: 'CRM.TRIGGER_FIELD_HELP',
    emptyKey: 'CRM.AUTOMATION_EMPTY_FIELD',
    railKey: 'CRM.AUTOMATION_RAIL_FIELD',
    webhookEvent: 'crm_deal_field_changed',
  },
};

export const createAction = (type, kind = 'stage') => ({
  key: crypto.randomUUID(),
  type,
  ...ACTION_TYPES[type].defaults(kind),
});

export const createCondition = () => ({
  custom_field_id: null,
  operator: 'equals',
  value: '',
});

const withKeys = items =>
  (items || []).map(item => ({ ...item, key: crypto.randomUUID() }));

export const cloneAutomations = actions =>
  (actions || []).map(action => ({
    ...action,
    key: crypto.randomUUID(),
    ...(action.routes ? { routes: withKeys(action.routes) } : {}),
  }));

const serializeCondition = ({ custom_field_id: fieldId, operator, value }) => ({
  custom_field_id: fieldId,
  operator,
  ...(isValuelessOperator(operator) ? {} : { value }),
});

const serializeRoute = ({ key, ...route }) =>
  isValuelessOperator(route.operator) ? { ...route, value: undefined } : route;

export const serializeAutomations = actions =>
  (actions || []).map(({ key, condition, routes, fallback, ...action }) => ({
    ...action,
    ...(routes ? { routes: routes.map(serializeRoute) } : {}),
    ...(fallback ? { fallback } : {}),
    ...(condition ? { condition: serializeCondition(condition) } : {}),
  }));

// Only RFC 3986 characters: the backend parses the URL with URI.parse and rejects anything else.
const WEBHOOK_URL = /^https?:\/\/[\w.~:/?#[\]@!$&'()*+,;=%-]+$/;
const ERROR_PREFIX = 'CRM.AUTOMATION_ERRORS.';
const isBlank = value => !value?.trim();

const ISO_DATE = /^\d{4}-\d{2}-\d{2}/;
const isComparable = value =>
  value.trim() !== '' && (!Number.isNaN(Number(value)) || ISO_DATE.test(value));
const stageAvailable = (destinations, pipelineId, stageId) =>
  !destinations ||
  destinations.some(
    pipeline =>
      pipeline.id === pipelineId &&
      pipeline.stages.some(stage => stage.id === stageId)
  );

// Error code of the value of a rule (a condition or a route), or '' when it is fine.
const getRuleValueError = ({ operator, value }) => {
  if (isValuelessOperator(operator)) return '';
  if (typeof value !== 'string' || isBlank(value)) return 'RULE_VALUE_REQUIRED';
  if (value.length > MAX_RULE_VALUE_LENGTH) return 'RULE_VALUE_TOO_LONG';
  if (ORDERED_OPERATORS.includes(operator) && !isComparable(value)) {
    return 'RULE_VALUE_NOT_COMPARABLE';
  }
  return '';
};

// Error code of a value typed for a custom field (what set_field writes), or '' when the field accepts it.
const getFieldValueError = (field, value) => {
  const { field_type: type, options = [] } = field;
  if (type === 'multiselect') {
    const items = Array.isArray(value) ? value : [];
    if (!items.length) return 'FIELD_VALUE_REQUIRED';
    return items.every(item => options.includes(item))
      ? ''
      : 'FIELD_VALUE_INVALID';
  }
  const text = typeof value === 'string' ? value : String(value ?? '');
  if (isBlank(text)) return 'FIELD_VALUE_REQUIRED';
  const valid = {
    select: () => options.includes(text),
    boolean: () => ['true', 'false'].includes(text),
    number: () => /^-?\d+(\.\d+)?$/.test(text),
    currency: () => /^-?\d+(\.\d+)?$/.test(text),
    date: () => /^\d{4}-\d{2}-\d{2}$/.test(text),
    datetime: () => !Number.isNaN(Date.parse(text)),
  }[type];
  return !valid || valid() ? '' : 'FIELD_VALUE_INVALID';
};

const getOperatorError = (operator, field) => {
  if (!getFieldOperators(field).includes(operator)) return 'OPTION_REQUIRED';
  return '';
};

export const getConditionErrors = (condition, { fields = null } = {}) => {
  const errors = {};
  const field = fields?.find(({ id }) => id === condition.custom_field_id);
  if (!Number.isInteger(condition.custom_field_id)) {
    errors.custom_field_id = `${ERROR_PREFIX}FIELD_REQUIRED`;
  } else if (fields && !field) {
    errors.custom_field_id = `${ERROR_PREFIX}FIELD_UNAVAILABLE`;
  }
  const operatorError = getOperatorError(condition.operator, field);
  if (operatorError) errors.operator = `${ERROR_PREFIX}${operatorError}`;
  else {
    const valueError = getRuleValueError(condition);
    if (valueError) errors.value = `${ERROR_PREFIX}${valueError}`;
  }
  return errors;
};

export const getDestinationErrors = (destination, destinations = null) => {
  const errors = {};
  if (!Number.isInteger(destination.pipeline_id)) {
    errors.pipeline_id = `${ERROR_PREFIX}PIPELINE_REQUIRED`;
  } else if (!Number.isInteger(destination.stage_id)) {
    errors.stage_id = `${ERROR_PREFIX}STAGE_REQUIRED`;
  } else if (
    !stageAvailable(destinations, destination.pipeline_id, destination.stage_id)
  ) {
    errors.stage_id = `${ERROR_PREFIX}STAGE_UNAVAILABLE`;
  }
  return errors;
};

export const getRouteErrors = (
  route,
  { destinations = null, field = null } = {}
) => {
  const errors = getDestinationErrors(route, destinations);
  const operatorError = getOperatorError(route.operator, field);
  if (operatorError) errors.operator = `${ERROR_PREFIX}${operatorError}`;
  else {
    const valueError = getRuleValueError(route);
    if (valueError) errors.value = `${ERROR_PREFIX}${valueError}`;
  }
  return errors;
};

export const getActionErrors = (
  action,
  { destinations = null, fields = null } = {}
) => {
  const errors = {};
  const fail = (field, code) => {
    errors[field] = `${ERROR_PREFIX}${code}`;
  };
  const customField = fields?.find(({ id }) => id === action.custom_field_id);
  const checkCustomField = () => {
    if (!Number.isInteger(action.custom_field_id)) {
      fail('custom_field_id', 'FIELD_REQUIRED');
    } else if (fields && !customField) {
      fail('custom_field_id', 'FIELD_UNAVAILABLE');
    }
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
    case 'assign_random':
      if (!Array.isArray(action.user_ids) || !action.user_ids.length) {
        fail('user_ids', 'OWNERS_REQUIRED');
      } else if (action.user_ids.length > MAX_RANDOM_OWNERS) {
        fail('user_ids', 'OWNERS_TOO_MANY');
      }
      break;
    case 'set_field': {
      checkCustomField();
      const valueError =
        customField && getFieldValueError(customField, action.value);
      if (!errors.custom_field_id && valueError) fail('value', valueError);
      break;
    }
    case 'route_by_field': {
      checkCustomField();
      const routes = Array.isArray(action.routes) ? action.routes : [];
      if (!routes.length) fail('routes', 'ROUTES_REQUIRED');
      else if (routes.length > MAX_ROUTES) fail('routes', 'ROUTES_TOO_MANY');
      else if (
        routes.some(
          route =>
            Object.keys(
              getRouteErrors(route, { destinations, field: customField })
            ).length
        )
      ) {
        fail('routes', 'ROUTES_INVALID');
      }
      if (
        action.fallback &&
        Object.keys(getDestinationErrors(action.fallback, destinations)).length
      ) {
        fail('fallback', 'FALLBACK_INVALID');
      }
      break;
    }
    default:
      fail('type', 'OPTION_REQUIRED');
  }
  if (
    action.condition &&
    Object.keys(getConditionErrors(action.condition, { fields })).length
  ) {
    fail('condition', 'CONDITION_INVALID');
  }
  return errors;
};

export const isAutomationValid = (action, context) =>
  !Object.keys(getActionErrors(action, context)).length;

const describeAction = (
  action,
  { t, agents, destinations = null, fields = null }
) => {
  const unset = t('CRM.AUTOMATION_SUMMARY_UNSET');
  if (!isAutomationValid(action)) return unset;
  const fieldName = id => fields?.find(item => item.id === id)?.name ?? unset;

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
    case 'assign_random': {
      const names = agents
        .filter(({ id }) => action.user_ids.includes(id))
        .map(({ name }) => name);
      return t('CRM.AUTOMATION_SUMMARY_RANDOM', {
        count: action.user_ids.length,
        names: names.join(', '),
      });
    }
    case 'set_field': {
      const { value } = action;
      return t('CRM.AUTOMATION_SUMMARY_SET_FIELD', {
        field: fieldName(action.custom_field_id),
        value: Array.isArray(value) ? value.join(', ') : String(value),
      });
    }
    case 'route_by_field':
      return t('CRM.AUTOMATION_SUMMARY_ROUTE', {
        field: fieldName(action.custom_field_id),
        count: action.routes.length,
      });
    default:
      return action.url;
  }
};

export const getActionSummary = (action, context) => {
  const summary = describeAction(action, context);
  const { condition } = action;
  if (!condition || !isAutomationValid(action)) return summary;

  const { t, fields = null } = context;
  const field = fields?.find(({ id }) => id === condition.custom_field_id);
  const operator = t(getOperatorLabelKey(condition.operator, field));
  const value = isValuelessOperator(condition.operator)
    ? ''
    : ` ${condition.value}`;
  return `${summary} · ${t('CRM.AUTOMATION_SUMMARY_CONDITION', {
    field: field?.name ?? '',
    condition: `${operator}${value}`,
  })}`;
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
