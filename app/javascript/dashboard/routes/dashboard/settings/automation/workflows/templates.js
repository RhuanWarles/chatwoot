import { createNode, newId } from './graph';
import { NODE_TYPES } from './constants';

const COLUMN = 340;
const ROW = 150;

const edge = (source, target, sourceHandle = 'out') => ({
  id: newId('edge'),
  source,
  sourceHandle,
  target,
});

const node = (type, column, row, data) => {
  const created = createNode(type, {
    position: { x: column * COLUMN, y: row * ROW },
    preset: data,
  });
  return { ...created, data: { ...created.data, ...data } };
};

const action = (column, row, name, params) =>
  node(NODE_TYPES.ACTION, column, row, {
    action: name,
    params,
    continue_on_error: false,
  });

/**
 * Trigger "deal lost" -> switch on the loss reason -> one "move deal" per reason.
 * Pipeline and stage are left empty on purpose: the user picks the destination of each reason.
 */
export const lostReasonRoutingTemplate = (reasons = []) => {
  const trigger = node(NODE_TYPES.TRIGGER, 0, 0, { event: 'crm_deal_lost' });
  const cases = reasons.map(reason => ({
    id: newId('case'),
    value: String(reason.id),
    label: reason.name,
  }));
  const router = node(NODE_TYPES.SWITCH, 1, 0, {
    field: 'deal.lost_reason_id',
    cases,
  });
  const moves = cases.map((item, index) =>
    action(2, index, 'move_deal', {
      pipeline_id: '',
      pipeline_stage_id: '',
      reopen: true,
    })
  );
  return {
    nodes: [trigger, router, ...moves],
    edges: [
      edge(trigger.id, router.id),
      ...cases.map((item, index) => edge(router.id, moves[index].id, item.id)),
    ],
  };
};

const welcomeTemplate = ({ t }) => {
  const trigger = node(NODE_TYPES.TRIGGER, 0, 0, {
    event: 'conversation_created',
  });
  const message = action(1, 0, 'send_message', {
    content: t('AUTOMATION.WORKFLOWS.TEMPLATES.WELCOME_MESSAGE.CONTENT'),
  });
  return { nodes: [trigger, message], edges: [edge(trigger.id, message.id)] };
};

const randomOwnerTemplate = () => {
  const trigger = node(NODE_TYPES.TRIGGER, 0, 0, { event: 'crm_deal_created' });
  const owner = action(1, 0, 'assign_deal_owner', {
    mode: 'random',
    user_id: '',
    user_ids: [],
  });
  return { nodes: [trigger, owner], edges: [edge(trigger.id, owner.id)] };
};

const wonWebhookTemplate = () => {
  const trigger = node(NODE_TYPES.TRIGGER, 0, 0, { event: 'crm_deal_won' });
  const request = action(1, 0, 'http_request', {
    method: 'POST',
    url: '',
    headers: [],
    body: '',
    include_payload: true,
  });
  return { nodes: [trigger, request], edges: [edge(trigger.id, request.id)] };
};

const staleFollowUpTemplate = ({ t }) => {
  const trigger = node(NODE_TYPES.TRIGGER, 0, 0, {
    event: 'crm_deal_stage_changed',
  });
  const wait = node(NODE_TYPES.WAIT, 1, 0, { amount: 2, unit: 'days' });
  const check = node(NODE_TYPES.CONDITION, 2, 0, {
    match: 'all',
    conditions: [{ field: 'deal.status', operator: 'equals', value: 'open' }],
  });
  const task = action(3, 0, 'create_deal_activity', {
    activity_type: 'follow_up',
    title: t('AUTOMATION.WORKFLOWS.TEMPLATES.FOLLOW_UP_TASK.TITLE'),
    due_in_hours: 4,
  });
  return {
    nodes: [trigger, wait, check, task],
    edges: [
      edge(trigger.id, wait.id),
      edge(wait.id, check.id),
      edge(check.id, task.id, 'true'),
    ],
  };
};

// build({ t, lostReasons }) returns a graph; `needsReasons` marks the template built from the loss reasons.
export const WORKFLOW_TEMPLATES = [
  {
    key: 'lost_reason_routing',
    icon: 'i-lucide-thumbs-down',
    needsReasons: true,
    build: ctx => lostReasonRoutingTemplate(ctx.lostReasons),
  },
  {
    key: 'welcome_message',
    icon: 'i-lucide-message-circle-plus',
    build: welcomeTemplate,
  },
  { key: 'random_owner', icon: 'i-lucide-shuffle', build: randomOwnerTemplate },
  { key: 'won_webhook', icon: 'i-lucide-webhook', build: wonWebhookTemplate },
  {
    key: 'follow_up_task',
    icon: 'i-lucide-calendar-plus',
    build: staleFollowUpTemplate,
  },
];

export const templateNameKey = key =>
  `AUTOMATION.WORKFLOWS.TEMPLATES.${key.toUpperCase()}.NAME`;
export const templateDescriptionKey = key =>
  `AUTOMATION.WORKFLOWS.TEMPLATES.${key.toUpperCase()}.DESCRIPTION`;
