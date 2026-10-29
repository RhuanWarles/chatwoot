// Field catalog used by conditions, switch nodes and the variable helper.
// `kind` decides which value input a field gets (see ValueInput.vue).
export const FIELD_KINDS = Object.freeze({
  TEXT: 'text',
  NUMBER: 'number',
  STATIC: 'static',
  PIPELINE: 'pipeline',
  STAGE: 'stage',
  AGENT: 'agent',
  TEAM: 'team',
  SEGMENT: 'segment',
  LOST_REASON: 'lost_reason',
  INBOX: 'inbox',
  OPTIONS: 'options',
});

// Kinds whose values are ids resolved through the lookups (kind === lookup list name).
export const ID_KINDS = [
  FIELD_KINDS.PIPELINE,
  FIELD_KINDS.STAGE,
  FIELD_KINDS.AGENT,
  FIELD_KINDS.TEAM,
  FIELD_KINDS.SEGMENT,
  FIELD_KINDS.LOST_REASON,
  FIELD_KINDS.INBOX,
];

export const FIELD_GROUPS = [
  'deal',
  'contact',
  'conversation',
  'message',
  'trigger',
  'vars',
];

// Fields whose last segment is typed by the user (webhook body path, variable name).
export const FREE_FIELD_PREFIXES = ['trigger.payload.', 'vars.'];

export const DEAL_CUSTOM_PREFIX = 'deal.custom.';
export const CONTACT_CUSTOM_PREFIX = 'contact.custom.';

const text = (key, group) => ({ key, group, kind: FIELD_KINDS.TEXT });
const idField = (key, group, kind) => ({ key, group, kind });
const staticField = (key, group, options) => ({
  key,
  group,
  kind: FIELD_KINDS.STATIC,
  options,
});

export const STATIC_FIELDS = [
  text('deal.name', 'deal'),
  staticField('deal.status', 'deal', 'DEAL_STATUS'),
  { key: 'deal.value', group: 'deal', kind: FIELD_KINDS.NUMBER },
  text('deal.description', 'deal'),
  idField('deal.pipeline_id', 'deal', FIELD_KINDS.PIPELINE),
  idField('deal.pipeline_stage_id', 'deal', FIELD_KINDS.STAGE),
  idField('deal.owner_id', 'deal', FIELD_KINDS.AGENT),
  idField('deal.segment_id', 'deal', FIELD_KINDS.SEGMENT),
  idField('deal.lost_reason_id', 'deal', FIELD_KINDS.LOST_REASON),
  text('deal.pipeline', 'deal'),
  text('deal.stage', 'deal'),
  text('deal.owner', 'deal'),
  text('deal.lost_reason', 'deal'),
  text('deal.lost_note', 'deal'),
  text('contact.name', 'contact'),
  text('contact.email', 'contact'),
  text('contact.phone_number', 'contact'),
  text('contact.labels', 'contact'),
  staticField('conversation.status', 'conversation', 'CONVERSATION_STATUS'),
  idField('conversation.inbox_id', 'conversation', FIELD_KINDS.INBOX),
  idField('conversation.assignee_id', 'conversation', FIELD_KINDS.AGENT),
  idField('conversation.team_id', 'conversation', FIELD_KINDS.TEAM),
  staticField('conversation.priority', 'conversation', 'PRIORITY'),
  text('conversation.labels', 'conversation'),
  text('message.content', 'message'),
  staticField('message.message_type', 'message', 'MESSAGE_TYPE'),
  text('trigger.event', 'trigger'),
  text('trigger.payload.', 'trigger'),
  idField('change.pipeline_stage_id.from', 'trigger', FIELD_KINDS.STAGE),
  idField('change.pipeline_stage_id.to', 'trigger', FIELD_KINDS.STAGE),
  idField('change.pipeline_id.from', 'trigger', FIELD_KINDS.PIPELINE),
  idField('change.pipeline_id.to', 'trigger', FIELD_KINDS.PIPELINE),
  staticField('change.status.from', 'trigger', 'DEAL_STATUS'),
  staticField('change.status.to', 'trigger', 'DEAL_STATUS'),
  text('vars.', 'vars'),
];

export const STATIC_FIELD_BY_KEY = Object.fromEntries(
  STATIC_FIELDS.map(field => [field.key, field])
);

export const freePrefixOf = field =>
  FREE_FIELD_PREFIXES.find(prefix => String(field || '').startsWith(prefix)) ||
  '';

const NUMERIC_TYPES = ['number', 'currency', 'percent'];

const customFieldKind = definition => {
  if (definition.options?.length || definition.attribute_values?.length) {
    return FIELD_KINDS.OPTIONS;
  }
  return NUMERIC_TYPES.includes(definition.field_type || definition.type)
    ? FIELD_KINDS.NUMBER
    : FIELD_KINDS.TEXT;
};

/**
 * Builds the custom field entries (deal custom fields and contact attributes).
 * dealFields: records of crm/custom_fields ({ key, name, field_type, options }).
 * contactAttributes: custom attribute definitions of the contact model
 * ({ attribute_key, attribute_display_name, attribute_values }).
 */
export const buildCustomFields = (dealFields = [], contactAttributes = []) => [
  ...dealFields
    .filter(item => item.active !== false)
    .map(item => ({
      key: `${DEAL_CUSTOM_PREFIX}${item.key}`,
      group: 'deal',
      kind: customFieldKind(item),
      label: item.name,
      choices: item.options || [],
    })),
  ...contactAttributes.map(item => ({
    key: `${CONTACT_CUSTOM_PREFIX}${item.attribute_key}`,
    group: 'contact',
    kind: customFieldKind(item),
    label: item.attribute_display_name,
    choices: item.attribute_values || [],
  })),
];

/**
 * Resolves the metadata of any field key, including `trigger.payload.x` and
 * `vars.x` (free fields) and custom fields.
 */
export const resolveField = (fieldKey, customFields = []) => {
  const key = String(fieldKey || '');
  const prefix = freePrefixOf(key);
  if (prefix) return STATIC_FIELD_BY_KEY[prefix] || null;
  return (
    STATIC_FIELD_BY_KEY[key] ||
    customFields.find(item => item.key === key) ||
    null
  );
};

export const fieldKindOf = (fieldKey, customFields = []) =>
  resolveField(fieldKey, customFields)?.kind || FIELD_KINDS.TEXT;

export const fieldLabelKey = fieldKey =>
  `AUTOMATION.WORKFLOWS.FIELDS.${String(fieldKey)
    .replace(/\./g, '_')
    .replace(/_+$/, '')
    .toUpperCase()}`;
