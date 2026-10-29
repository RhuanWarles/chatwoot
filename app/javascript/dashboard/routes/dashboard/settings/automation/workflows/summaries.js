import { ACTION_BY_KEY } from './actions';
import {
  NODE_TYPES,
  OPERATOR_BY_KEY,
  actionLabelKey,
  operatorLabelKey,
  optionLabelKey,
  triggerLabelKey,
} from './constants';
import {
  FIELD_KINDS,
  ID_KINDS,
  fieldKindOf,
  fieldLabelKey,
  resolveField,
} from './fields';

const MAX_TEXT = 60;

const truncate = (value, max = MAX_TEXT) => {
  const text = String(value ?? '')
    .replace(/\s+/g, ' ')
    .trim();
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
};

/**
 * ctx: { t, name(kind, id), customFields } - `name` resolves ids to display names.
 */
export const fieldLabel = (field, ctx) => {
  if (!field) return ctx.t('AUTOMATION.WORKFLOWS.SUMMARY.NO_FIELD');
  const meta = resolveField(field, ctx.customFields);
  if (meta?.label) return meta.label;
  const prefix = ['trigger.payload.', 'vars.'].find(item =>
    field.startsWith(item)
  );
  if (prefix)
    return `${ctx.t(fieldLabelKey(prefix))} ${field.slice(prefix.length)}`.trim();
  return meta ? ctx.t(fieldLabelKey(field)) : field;
};

export const valueLabel = (field, value, ctx) => {
  if (Array.isArray(value)) {
    return value.map(item => valueLabel(field, item, ctx)).join(', ');
  }
  const meta = resolveField(field, ctx.customFields);
  const kind = fieldKindOf(field, ctx.customFields);
  if (ID_KINDS.includes(kind)) return ctx.name(kind, value);
  if (kind === FIELD_KINDS.STATIC && meta?.options) {
    return ctx.t(optionLabelKey(meta.options, value));
  }
  return String(value ?? '');
};

const conditionText = (condition, ctx) => {
  const operator = OPERATOR_BY_KEY[condition.operator];
  const parts = [
    fieldLabel(condition.field, ctx),
    ctx.t(operatorLabelKey(condition.operator)),
  ];
  if (!operator?.noValue)
    parts.push(truncate(valueLabel(condition.field, condition.value, ctx), 30));
  return parts.join(' ');
};

const optionText = (list, value, ctx) => ctx.t(optionLabelKey(list, value));

const withSpecial = (value, ctx, resolve) =>
  ['nil', 'last_responding_agent'].includes(String(value))
    ? ctx.t(`AUTOMATION.WORKFLOWS.SPECIAL.${String(value).toUpperCase()}`)
    : resolve(value);

const fieldsText = fields =>
  truncate(
    (fields || [])
      .filter(item => item.key)
      .map(item => `${item.key} = ${item.value ?? ''}`)
      .join(', ')
  );

const ACTION_DETAILS = {
  send_message: params => truncate(params.content),
  add_private_note: params => truncate(params.content),
  assign_agent: (params, ctx) =>
    withSpecial(params.agent_id, ctx, id => ctx.name('agent', id)),
  assign_team: (params, ctx) =>
    withSpecial(params.team_id, ctx, id => ctx.name('team', id)),
  add_label: params => (params.labels || []).join(', '),
  remove_label: params => (params.labels || []).join(', '),
  add_contact_label: params => (params.labels || []).join(', '),
  change_status: (params, ctx) =>
    optionText('CONVERSATION_STATUS', params.status, ctx),
  change_priority: (params, ctx) =>
    optionText('PRIORITY', params.priority, ctx),
  move_deal: (params, ctx) =>
    params.pipeline_id
      ? `${ctx.name('pipeline', params.pipeline_id)} › ${ctx.name('stage', params.pipeline_stage_id)}`
      : '',
  create_deal: (params, ctx) =>
    params.pipeline_id
      ? `${ctx.name('pipeline', params.pipeline_id)} › ${ctx.name('stage', params.pipeline_stage_id)}`
      : '',
  set_deal_status: (params, ctx) => {
    const status = optionText('DEAL_STATUS', params.status, ctx);
    return params.status === 'lost' && params.lost_reason_id
      ? `${status} · ${ctx.name('lost_reason', params.lost_reason_id)}`
      : status;
  },
  assign_deal_owner: (params, ctx) => {
    if (params.mode === 'user') return ctx.name('agent', params.user_id);
    if (params.mode === 'random') {
      return ctx.t('AUTOMATION.WORKFLOWS.SUMMARY.RANDOM_OF', {
        n: (params.user_ids || []).length,
      });
    }
    return optionText('OWNER_MODE', params.mode, ctx);
  },
  update_deal: (params, ctx) =>
    ctx.t('AUTOMATION.WORKFLOWS.SUMMARY.UPDATE_DEAL', {
      n: ['name', 'value', 'description', 'segment_id'].filter(
        key => params[key]
      ).length,
    }),
  set_deal_field: params => fieldsText(params.fields),
  set_contact_field: params => fieldsText(params.fields),
  create_deal_activity: params => truncate(params.title),
  http_request: params =>
    truncate(`${params.method || ''} ${params.url || ''}`),
  set_variable: params =>
    truncate(`${params.name || ''} = ${params.value || ''}`),
};

const actionDetail = (data, ctx) => {
  const params = data.params || {};
  const detail = ACTION_DETAILS[data.action]?.(params, ctx) || '';
  return detail.trim();
};

/**
 * Returns { title, detail } for a node: `title` is the kind of block (trigger name, action name,
 * ...) and `detail` the one-line configuration summary shown inside the node.
 */
export const summarizeNode = (node, ctx) => {
  const data = node.data || {};
  const { t } = ctx;
  switch (node.type) {
    case NODE_TYPES.TRIGGER:
      return {
        title: t('AUTOMATION.WORKFLOWS.NODE_TYPES.TRIGGER'),
        detail: t(triggerLabelKey(data.event)),
      };
    case NODE_TYPES.CONDITION: {
      const [first, ...rest] = data.conditions || [];
      const detail = first
        ? conditionText(first, ctx)
        : t('AUTOMATION.WORKFLOWS.SUMMARY.NO_CONDITIONS');
      return {
        title: t('AUTOMATION.WORKFLOWS.NODE_TYPES.CONDITION'),
        detail: rest.length
          ? t('AUTOMATION.WORKFLOWS.SUMMARY.AND_MORE', {
              text: detail,
              n: rest.length,
            })
          : detail,
      };
    }
    case NODE_TYPES.SWITCH:
      return {
        title: t('AUTOMATION.WORKFLOWS.NODE_TYPES.SWITCH'),
        detail: data.field
          ? t('AUTOMATION.WORKFLOWS.SUMMARY.SWITCH', {
              field: fieldLabel(data.field, ctx),
              n: (data.cases || []).length,
            })
          : t('AUTOMATION.WORKFLOWS.SUMMARY.NO_FIELD'),
      };
    case NODE_TYPES.WAIT:
      return {
        title: t('AUTOMATION.WORKFLOWS.NODE_TYPES.WAIT'),
        detail: t('AUTOMATION.WORKFLOWS.SUMMARY.WAIT', {
          amount: data.amount,
          unit: optionText('WAIT_UNIT', data.unit, ctx),
        }),
      };
    default:
      return {
        title: ACTION_BY_KEY[data.action]
          ? t(actionLabelKey(data.action))
          : t('AUTOMATION.WORKFLOWS.NODE_TYPES.ACTION'),
        detail: actionDetail(data, ctx),
      };
  }
};

// Label of a switch case handle: the explicit label, or the resolved value.
export const caseLabel = (switchData, item, ctx) =>
  item.label ||
  valueLabel(switchData.field, item.value, ctx) ||
  ctx.t('AUTOMATION.WORKFLOWS.SWITCH.EMPTY_CASE');
