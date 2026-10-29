export const PARAM_TYPES = Object.freeze({
  TEMPLATE_TEXT: 'template_text',
  TEMPLATE_LINE: 'template_line',
  NUMBER: 'number',
  CHECKBOX: 'checkbox',
  STATIC: 'static',
  AGENT: 'agent',
  AGENTS_MULTI: 'agents_multi',
  TEAM: 'team',
  LABELS: 'labels',
  PIPELINE: 'pipeline',
  STAGE: 'stage',
  SEGMENT: 'segment',
  LOST_REASON: 'lost_reason',
  DEAL_FIELDS: 'deal_fields',
  CONTACT_FIELDS: 'contact_fields',
  HEADERS: 'headers',
});

export const ACTION_GROUPS = ['conversation', 'deal', 'contact', 'integration'];

const param = (key, type, extra = {}) => ({ key, type, ...extra });

// requires: the entity the step needs in the run context (informational, shown as a hint).
// atLeastOne: a list of params of which at least one must be filled.
export const ACTIONS = [
  {
    key: 'send_message',
    group: 'conversation',
    icon: 'i-lucide-send',
    requires: 'conversation',
    params: [param('content', PARAM_TYPES.TEMPLATE_TEXT, { required: true })],
    defaults: { content: '' },
  },
  {
    key: 'add_private_note',
    group: 'conversation',
    icon: 'i-lucide-sticky-note',
    requires: 'conversation',
    params: [param('content', PARAM_TYPES.TEMPLATE_TEXT, { required: true })],
    defaults: { content: '' },
  },
  {
    key: 'assign_agent',
    group: 'conversation',
    icon: 'i-lucide-user-round-plus',
    requires: 'conversation',
    params: [
      param('agent_id', PARAM_TYPES.AGENT, {
        required: true,
        specials: ['nil', 'last_responding_agent'],
      }),
    ],
    defaults: { agent_id: '' },
  },
  {
    key: 'assign_team',
    group: 'conversation',
    icon: 'i-lucide-users',
    requires: 'conversation',
    params: [
      param('team_id', PARAM_TYPES.TEAM, { required: true, specials: ['nil'] }),
    ],
    defaults: { team_id: '' },
  },
  {
    key: 'add_label',
    group: 'conversation',
    icon: 'i-lucide-tag',
    requires: 'conversation',
    params: [param('labels', PARAM_TYPES.LABELS, { required: true })],
    defaults: { labels: [] },
  },
  {
    key: 'remove_label',
    group: 'conversation',
    icon: 'i-lucide-eraser',
    requires: 'conversation',
    params: [param('labels', PARAM_TYPES.LABELS, { required: true })],
    defaults: { labels: [] },
  },
  {
    key: 'change_status',
    group: 'conversation',
    icon: 'i-lucide-circle-dot',
    requires: 'conversation',
    params: [
      param('status', PARAM_TYPES.STATIC, {
        required: true,
        options: 'CONVERSATION_STATUS',
      }),
    ],
    defaults: { status: 'resolved' },
  },
  {
    key: 'change_priority',
    group: 'conversation',
    icon: 'i-lucide-signal',
    requires: 'conversation',
    params: [
      param('priority', PARAM_TYPES.STATIC, {
        required: true,
        options: 'PRIORITY',
      }),
    ],
    defaults: { priority: 'high' },
  },
  {
    key: 'move_deal',
    group: 'deal',
    icon: 'i-lucide-move-right',
    requires: 'deal',
    params: [
      param('pipeline_id', PARAM_TYPES.PIPELINE, { required: true }),
      param('pipeline_stage_id', PARAM_TYPES.STAGE, { required: true }),
      param('reopen', PARAM_TYPES.CHECKBOX),
    ],
    defaults: { pipeline_id: '', pipeline_stage_id: '', reopen: true },
  },
  {
    key: 'set_deal_status',
    group: 'deal',
    icon: 'i-lucide-flag',
    requires: 'deal',
    params: [
      param('status', PARAM_TYPES.STATIC, {
        required: true,
        options: 'DEAL_STATUS',
      }),
      param('lost_reason_id', PARAM_TYPES.LOST_REASON, {
        showWhen: params => params.status === 'lost',
      }),
      param('lost_note', PARAM_TYPES.TEMPLATE_LINE, {
        showWhen: params => params.status === 'lost',
      }),
    ],
    defaults: { status: 'won' },
  },
  {
    key: 'assign_deal_owner',
    group: 'deal',
    icon: 'i-lucide-user-round-cog',
    requires: 'deal',
    params: [
      param('mode', PARAM_TYPES.STATIC, {
        required: true,
        options: 'OWNER_MODE',
      }),
      param('user_id', PARAM_TYPES.AGENT, {
        showWhen: params => params.mode === 'user',
        requiredWhen: params => params.mode === 'user',
      }),
      param('user_ids', PARAM_TYPES.AGENTS_MULTI, {
        showWhen: params => params.mode === 'random',
        requiredWhen: params => params.mode === 'random',
      }),
    ],
    defaults: { mode: 'user', user_id: '', user_ids: [] },
  },
  {
    key: 'update_deal',
    group: 'deal',
    icon: 'i-lucide-pencil-line',
    requires: 'deal',
    atLeastOne: ['name', 'value', 'description', 'segment_id'],
    params: [
      param('name', PARAM_TYPES.TEMPLATE_LINE),
      param('value', PARAM_TYPES.TEMPLATE_LINE),
      param('description', PARAM_TYPES.TEMPLATE_TEXT),
      param('segment_id', PARAM_TYPES.SEGMENT),
    ],
    defaults: {},
  },
  {
    key: 'set_deal_field',
    group: 'deal',
    icon: 'i-lucide-text-cursor-input',
    requires: 'deal',
    params: [param('fields', PARAM_TYPES.DEAL_FIELDS, { required: true })],
    defaults: { fields: [] },
  },
  {
    key: 'create_deal',
    group: 'deal',
    icon: 'i-lucide-handshake',
    requires: 'contact',
    params: [
      param('pipeline_id', PARAM_TYPES.PIPELINE, { required: true }),
      param('pipeline_stage_id', PARAM_TYPES.STAGE, { required: true }),
      param('name', PARAM_TYPES.TEMPLATE_LINE),
      param('value', PARAM_TYPES.TEMPLATE_LINE),
      param('owner_id', PARAM_TYPES.AGENT),
    ],
    defaults: { pipeline_id: '', pipeline_stage_id: '' },
  },
  {
    key: 'create_deal_activity',
    group: 'deal',
    icon: 'i-lucide-calendar-plus',
    requires: 'deal',
    params: [
      param('activity_type', PARAM_TYPES.STATIC, {
        required: true,
        options: 'ACTIVITY_TYPE',
      }),
      param('title', PARAM_TYPES.TEMPLATE_LINE, { required: true }),
      param('due_in_hours', PARAM_TYPES.NUMBER, { required: true }),
    ],
    defaults: { activity_type: 'task', title: '', due_in_hours: 24 },
  },
  {
    key: 'set_contact_field',
    group: 'contact',
    icon: 'i-lucide-user-pen',
    requires: 'contact',
    params: [param('fields', PARAM_TYPES.CONTACT_FIELDS, { required: true })],
    defaults: { fields: [] },
  },
  {
    key: 'add_contact_label',
    group: 'contact',
    icon: 'i-lucide-tags',
    requires: 'contact',
    params: [param('labels', PARAM_TYPES.LABELS, { required: true })],
    defaults: { labels: [] },
  },
  {
    key: 'http_request',
    group: 'integration',
    icon: 'i-lucide-globe',
    requires: null,
    params: [
      param('method', PARAM_TYPES.STATIC, {
        required: true,
        options: 'HTTP_METHOD',
      }),
      param('url', PARAM_TYPES.TEMPLATE_LINE, { required: true }),
      param('headers', PARAM_TYPES.HEADERS),
      param('include_payload', PARAM_TYPES.CHECKBOX),
      param('body', PARAM_TYPES.TEMPLATE_TEXT, {
        showWhen: params => !params.include_payload,
      }),
    ],
    defaults: {
      method: 'POST',
      url: '',
      headers: [],
      body: '',
      include_payload: true,
    },
  },
  {
    key: 'set_variable',
    group: 'integration',
    icon: 'i-lucide-variable',
    requires: null,
    params: [
      param('name', PARAM_TYPES.TEMPLATE_LINE, { required: true, plain: true }),
      param('value', PARAM_TYPES.TEMPLATE_LINE),
    ],
    defaults: { name: '', value: '' },
  },
];

export const ACTION_BY_KEY = Object.fromEntries(
  ACTIONS.map(action => [action.key, action])
);
