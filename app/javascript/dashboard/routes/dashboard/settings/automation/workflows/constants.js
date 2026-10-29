import { ACTION_BY_KEY } from './actions';

export const NODE_TYPES = Object.freeze({
  TRIGGER: 'trigger',
  CONDITION: 'condition',
  SWITCH: 'switch',
  WAIT: 'wait',
  ACTION: 'action',
});

export const MAX_NODES = 100;
export const DEFAULT_HANDLE = 'out';
export const DEFAULT_CASE_HANDLE = 'default';
export const WAIT_UNITS = ['minutes', 'hours', 'days'];
export const MATCH_MODES = ['all', 'any'];

export const TRIGGER_GROUPS = ['conversation', 'contact', 'crm', 'other'];

export const TRIGGER_EVENTS = [
  {
    key: 'conversation_created',
    group: 'conversation',
    icon: 'i-lucide-message-circle-plus',
  },
  {
    key: 'conversation_opened',
    group: 'conversation',
    icon: 'i-lucide-message-circle',
  },
  {
    key: 'conversation_resolved',
    group: 'conversation',
    icon: 'i-lucide-circle-check',
  },
  {
    key: 'message_created',
    group: 'conversation',
    icon: 'i-lucide-messages-square',
  },
  {
    key: 'assignee_changed',
    group: 'conversation',
    icon: 'i-lucide-user-round-check',
  },
  { key: 'team_changed', group: 'conversation', icon: 'i-lucide-users-round' },
  { key: 'contact_created', group: 'contact', icon: 'i-lucide-user-plus' },
  { key: 'contact_updated', group: 'contact', icon: 'i-lucide-user-pen' },
  { key: 'crm_deal_created', group: 'crm', icon: 'i-lucide-handshake' },
  { key: 'crm_deal_updated', group: 'crm', icon: 'i-lucide-pencil' },
  { key: 'crm_deal_stage_changed', group: 'crm', icon: 'i-lucide-columns-3' },
  { key: 'crm_deal_status_changed', group: 'crm', icon: 'i-lucide-flag' },
  {
    key: 'crm_deal_pipeline_changed',
    group: 'crm',
    icon: 'i-lucide-git-branch',
  },
  {
    key: 'crm_deal_field_changed',
    group: 'crm',
    icon: 'i-lucide-text-cursor-input',
  },
  { key: 'crm_deal_won', group: 'crm', icon: 'i-lucide-trophy' },
  { key: 'crm_deal_lost', group: 'crm', icon: 'i-lucide-thumbs-down' },
  { key: 'webhook', group: 'other', icon: 'i-lucide-webhook' },
  { key: 'manual', group: 'other', icon: 'i-lucide-play' },
];

export const TRIGGER_EVENT_KEYS = TRIGGER_EVENTS.map(item => item.key);

// `noValue` operators ignore the value; `multi` operators take an array.
export const OPERATORS = [
  { key: 'equals' },
  { key: 'not_equals' },
  { key: 'contains' },
  { key: 'not_contains' },
  { key: 'starts_with' },
  { key: 'ends_with' },
  { key: 'gt' },
  { key: 'gte' },
  { key: 'lt' },
  { key: 'lte' },
  { key: 'is_present', noValue: true },
  { key: 'is_blank', noValue: true },
  { key: 'in', multi: true },
  { key: 'not_in', multi: true },
];

export const OPERATOR_BY_KEY = Object.fromEntries(
  OPERATORS.map(operator => [operator.key, operator])
);

// Static option lists: the labels live under AUTOMATION.WORKFLOWS.OPTIONS.<LIST>.<VALUE>.
export const STATIC_OPTIONS = {
  CONVERSATION_STATUS: ['open', 'resolved', 'pending', 'snoozed'],
  PRIORITY: ['urgent', 'high', 'medium', 'low', 'nil'],
  DEAL_STATUS: ['open', 'won', 'lost'],
  ACTIVITY_TYPE: ['task', 'call', 'meeting', 'follow_up'],
  HTTP_METHOD: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  OWNER_MODE: ['user', 'random', 'conversation_assignee'],
  MESSAGE_TYPE: ['incoming', 'outgoing'],
  WAIT_UNIT: WAIT_UNITS,
  MATCH: MATCH_MODES,
};

export const optionLabelKey = (list, value) =>
  `AUTOMATION.WORKFLOWS.OPTIONS.${list}.${String(value).toUpperCase()}`;

export const triggerLabelKey = event =>
  `AUTOMATION.WORKFLOWS.TRIGGERS.${String(event).toUpperCase()}`;

export const actionLabelKey = action =>
  `AUTOMATION.WORKFLOWS.ACTIONS.${String(action).toUpperCase()}`;

export const operatorLabelKey = operator =>
  `AUTOMATION.WORKFLOWS.OPERATORS.${String(operator).toUpperCase()}`;

export const NODE_CATEGORY = {
  trigger: 'trigger',
  condition: 'logic',
  switch: 'logic',
  wait: 'logic',
  action: 'action',
};

// Variables offered by the helper that inserts {{...}} tokens into text params.
export const TEMPLATE_VARIABLES = [
  {
    group: 'deal',
    keys: [
      'deal.name',
      'deal.status',
      'deal.value',
      'deal.pipeline',
      'deal.stage',
      'deal.owner',
      'deal.lost_reason',
      'deal.lost_note',
    ],
  },
  {
    group: 'contact',
    keys: ['contact.name', 'contact.email', 'contact.phone_number'],
  },
  {
    group: 'conversation',
    keys: [
      'conversation.status',
      'conversation.priority',
      'conversation.labels',
    ],
  },
  { group: 'message', keys: ['message.content'] },
  { group: 'trigger', keys: ['trigger.event'] },
];

export const NODE_ICONS = {
  trigger: 'i-lucide-zap',
  condition: 'i-lucide-split',
  switch: 'i-lucide-git-fork',
  wait: 'i-lucide-timer',
  action: 'i-lucide-play',
};

export const nodeIcon = node => {
  if (node.type === NODE_TYPES.TRIGGER) {
    return (
      TRIGGER_EVENTS.find(item => item.key === node.data?.event)?.icon ||
      NODE_ICONS.trigger
    );
  }
  if (node.type === NODE_TYPES.ACTION) {
    return ACTION_BY_KEY[node.data?.action]?.icon || NODE_ICONS.action;
  }
  return NODE_ICONS[node.type];
};
