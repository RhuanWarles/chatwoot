import { ACTION_BY_KEY, PARAM_TYPES } from './actions';
import {
  DEFAULT_CASE_HANDLE,
  DEFAULT_HANDLE,
  MAX_NODES,
  NODE_TYPES,
  OPERATOR_BY_KEY,
  TRIGGER_EVENT_KEYS,
  WAIT_UNITS,
} from './constants';
import { FREE_FIELD_PREFIXES } from './fields';

const EDGE_MARKER = 'arrowclosed';
const NODE_OFFSET = 36;

const randomChunk = () => Math.random().toString(36).slice(2, 8);

export const newId = prefix => `${prefix}_${randomChunk()}${randomChunk()}`;

const clone = value => JSON.parse(JSON.stringify(value ?? null));

export const emptyCondition = () => ({
  field: '',
  operator: 'equals',
  value: '',
});

export const defaultParams = action =>
  clone(ACTION_BY_KEY[action]?.defaults || {});

export const defaultNodeData = (type, preset = {}) => {
  switch (type) {
    case NODE_TYPES.TRIGGER:
      return { event: preset.event || 'conversation_created' };
    case NODE_TYPES.CONDITION:
      return { match: 'all', conditions: [emptyCondition()] };
    case NODE_TYPES.SWITCH:
      return { field: '', cases: [] };
    case NODE_TYPES.WAIT:
      return { amount: 1, unit: 'hours' };
    default:
      return {
        action: preset.action,
        params: defaultParams(preset.action),
        continue_on_error: false,
      };
  }
};

export const createNode = (
  type,
  { position = { x: 0, y: 0 }, preset } = {}
) => ({
  id: newId(type),
  type,
  position,
  data: defaultNodeData(type, preset),
});

export const hasInput = node => node.type !== NODE_TYPES.TRIGGER;

// Output handles of a node. `tone` colors the handle, `label` is only set for switch cases
// (the other labels are translated by the node component from the handle id).
export const outputHandles = node => {
  if (node.type === NODE_TYPES.CONDITION) {
    return [
      { id: 'true', tone: 'positive' },
      { id: 'false', tone: 'negative' },
    ];
  }
  if (node.type === NODE_TYPES.SWITCH) {
    const cases = (node.data?.cases || []).map(item => ({
      id: item.id,
      tone: 'neutral',
      caseValue: item.value,
      label: item.label,
    }));
    return [...cases, { id: DEFAULT_CASE_HANDLE, tone: 'muted' }];
  }
  return [{ id: DEFAULT_HANDLE, tone: 'neutral' }];
};

const adjacency = edges => {
  const map = new Map();
  edges.forEach(edge => {
    if (!map.has(edge.source)) map.set(edge.source, []);
    map.get(edge.source).push(edge.target);
  });
  return map;
};

const reachableFrom = (startIds, edges) => {
  const next = adjacency(edges);
  const seen = new Set(startIds);
  const queue = [...startIds];
  while (queue.length) {
    (next.get(queue.shift()) || []).forEach(target => {
      if (!seen.has(target)) {
        seen.add(target);
        queue.push(target);
      }
    });
  }
  return seen;
};

// Adding source -> target closes a loop when source is already reachable from target.
export const wouldCreateCycle = (edges, sourceId, targetId) => {
  if (sourceId === targetId) return true;
  return reachableFrom([targetId], edges).has(sourceId);
};

export const hasCycle = (nodes, edges) => {
  const indegree = new Map(nodes.map(node => [node.id, 0]));
  edges.forEach(edge => {
    if (indegree.has(edge.target)) {
      indegree.set(edge.target, indegree.get(edge.target) + 1);
    }
  });
  const next = adjacency(edges);
  const queue = [...indegree]
    .filter(([, count]) => count === 0)
    .map(([id]) => id);
  let visited = 0;
  while (queue.length) {
    const id = queue.shift();
    visited += 1;
    (next.get(id) || []).forEach(target => {
      indegree.set(target, indegree.get(target) - 1);
      if (indegree.get(target) === 0) queue.push(target);
    });
  }
  return visited < nodes.length;
};

/**
 * Whether `connection` ({ source, sourceHandle, target }) can be added to the graph.
 * Returns an error code (MISSING_NODE, SELF_LOOP, TRIGGER_INPUT, UNKNOWN_HANDLE, DUPLICATE or
 * CYCLE) or '' when the connection is allowed.
 */
export const connectionError = (nodes, edges, connection) => {
  const source = nodes.find(node => node.id === connection.source);
  const target = nodes.find(node => node.id === connection.target);
  if (!source || !target) return 'MISSING_NODE';
  if (source.id === target.id) return 'SELF_LOOP';
  if (!hasInput(target)) return 'TRIGGER_INPUT';
  const handle = connection.sourceHandle || DEFAULT_HANDLE;
  if (!outputHandles(source).some(item => item.id === handle)) {
    return 'UNKNOWN_HANDLE';
  }
  const duplicate = edges.some(
    edge =>
      edge.source === source.id &&
      (edge.sourceHandle || DEFAULT_HANDLE) === handle &&
      edge.target === target.id
  );
  if (duplicate) return 'DUPLICATE';
  return wouldCreateCycle(edges, source.id, target.id) ? 'CYCLE' : '';
};

export const createEdge = connection => ({
  id: newId('edge'),
  source: connection.source,
  sourceHandle: connection.sourceHandle || DEFAULT_HANDLE,
  target: connection.target,
  markerEnd: EDGE_MARKER,
});

const roundPosition = position => ({
  x: Math.round(position?.x || 0),
  y: Math.round(position?.y || 0),
});

// Strips the runtime fields Vue Flow adds, leaving exactly the contract shape.
export const serializeGraph = (nodes, edges) => ({
  nodes: nodes.map(node => ({
    id: node.id,
    type: node.type,
    position: roundPosition(node.position),
    data: clone(node.data),
  })),
  edges: edges.map(edge => ({
    id: edge.id,
    source: edge.source,
    sourceHandle: edge.sourceHandle || DEFAULT_HANDLE,
    target: edge.target,
  })),
});

// Builds Vue Flow elements from a stored graph, dropping edges that point at missing nodes.
export const hydrateGraph = graph => {
  const nodes = (graph?.nodes || []).map(node => {
    const data = {
      ...defaultNodeData(node.type, node.data),
      ...clone(node.data),
    };
    if (node.type === NODE_TYPES.ACTION) {
      data.params = { ...defaultParams(data.action), ...data.params };
    }
    return {
      id: node.id,
      type: node.type,
      position: roundPosition(node.position),
      data,
    };
  });
  const ids = new Set(nodes.map(node => node.id));
  const edges = (graph?.edges || [])
    .filter(edge => ids.has(edge.source) && ids.has(edge.target))
    .map(edge => ({
      id: edge.id || newId('edge'),
      source: edge.source,
      sourceHandle: edge.sourceHandle || DEFAULT_HANDLE,
      target: edge.target,
      markerEnd: EDGE_MARKER,
    }));
  return { nodes, edges };
};

export const triggerEventsOf = nodes => [
  ...new Set(
    nodes
      .filter(node => node.type === NODE_TYPES.TRIGGER && node.data?.event)
      .map(node => node.data.event)
  ),
];

// A new node lands near `center` and is nudged until it no longer sits on top of another one.
export const findFreePosition = (nodes, center) => {
  const position = { x: Math.round(center.x), y: Math.round(center.y) };
  const taken = candidate =>
    nodes.some(
      node =>
        Math.abs(node.position.x - candidate.x) < NODE_OFFSET &&
        Math.abs(node.position.y - candidate.y) < NODE_OFFSET
    );
  while (taken(position)) {
    position.x += NODE_OFFSET;
    position.y += NODE_OFFSET;
  }
  return position;
};

export const isFilled = value => {
  if (Array.isArray(value)) return value.length > 0;
  if (typeof value === 'number') return Number.isFinite(value);
  if (typeof value === 'string') return value.trim() !== '';
  return value !== null && value !== undefined && value !== false;
};

// A bare `trigger.payload.` or `vars.` still needs the path the user types after it.
const isCompleteField = field =>
  isFilled(field) && !FREE_FIELD_PREFIXES.includes(field);

const FIELD_LIST_TYPES = [PARAM_TYPES.DEAL_FIELDS, PARAM_TYPES.CONTACT_FIELDS];

const paramIssue = (definition, params) => {
  if (definition.showWhen && !definition.showWhen(params)) return null;
  const required =
    definition.required ||
    (definition.requiredWhen && definition.requiredWhen(params));
  if (!required) return null;
  const value = params[definition.key];
  if (!isFilled(value)) return definition.key;
  if (FIELD_LIST_TYPES.includes(definition.type)) {
    return value.every(item => isFilled(item?.key)) ? null : definition.key;
  }
  return null;
};

const conditionIssue = condition => {
  if (!isCompleteField(condition.field)) return 'CONDITION_INCOMPLETE';
  const operator = OPERATOR_BY_KEY[condition.operator];
  if (!operator) return 'CONDITION_INCOMPLETE';
  if (operator.noValue) return null;
  return isFilled(condition.value) ? null : 'CONDITION_INCOMPLETE';
};

const nodeIssues = node => {
  const data = node.data || {};
  switch (node.type) {
    case NODE_TYPES.TRIGGER:
      return TRIGGER_EVENT_KEYS.includes(data.event)
        ? []
        : [{ code: 'EVENT_REQUIRED' }];
    case NODE_TYPES.CONDITION: {
      if (!data.conditions?.length) return [{ code: 'CONDITIONS_REQUIRED' }];
      return data.conditions.some(conditionIssue)
        ? [{ code: 'CONDITION_INCOMPLETE' }]
        : [];
    }
    case NODE_TYPES.SWITCH: {
      if (!isCompleteField(data.field))
        return [{ code: 'SWITCH_FIELD_REQUIRED' }];
      if (!data.cases?.length) return [{ code: 'SWITCH_CASES_REQUIRED' }];
      return data.cases.every(item => isFilled(item.value))
        ? []
        : [{ code: 'SWITCH_CASE_VALUE' }];
    }
    case NODE_TYPES.WAIT:
      return Number(data.amount) > 0 && WAIT_UNITS.includes(data.unit)
        ? []
        : [{ code: 'WAIT_AMOUNT' }];
    default: {
      const action = ACTION_BY_KEY[data.action];
      if (!action) return [{ code: 'ACTION_REQUIRED' }];
      const params = data.params || {};
      const issues = action.params
        .map(definition => paramIssue(definition, params))
        .filter(Boolean)
        .map(param => ({ code: 'PARAM_REQUIRED', param }));
      if (
        action.atLeastOne &&
        !action.atLeastOne.some(key => isFilled(params[key]))
      ) {
        issues.push({ code: 'AT_LEAST_ONE' });
      }
      return issues;
    }
  }
};

/**
 * Mirrors the server rules. Returns `{ issues: [{ nodeId?, code, param? }], byNode }` where
 * `byNode` maps a node id to its issues. Codes map to AUTOMATION.WORKFLOWS.VALIDATION.<CODE>.
 */
export const validateGraph = (nodes, edges) => {
  const issues = [];
  const triggers = nodes.filter(node => node.type === NODE_TYPES.TRIGGER);
  if (!triggers.length) issues.push({ code: 'NO_TRIGGER' });
  if (nodes.length > MAX_NODES) issues.push({ code: 'TOO_MANY_NODES' });
  if (hasCycle(nodes, edges)) issues.push({ code: 'CYCLE' });

  const reachable = reachableFrom(
    triggers.map(node => node.id),
    edges
  );
  nodes.forEach(node => {
    if (node.type !== NODE_TYPES.TRIGGER && !reachable.has(node.id)) {
      issues.push({ nodeId: node.id, code: 'UNREACHABLE' });
    }
    nodeIssues(node).forEach(issue =>
      issues.push({ nodeId: node.id, ...issue })
    );
  });

  const byNode = {};
  issues
    .filter(issue => issue.nodeId)
    .forEach(issue => {
      byNode[issue.nodeId] = [...(byNode[issue.nodeId] || []), issue];
    });
  return { issues, byNode, valid: issues.length === 0 };
};

export const graphSignature = ({ name, description, active, nodes, edges }) =>
  JSON.stringify({
    name: name || '',
    description: description || '',
    active: Boolean(active),
    graph: serializeGraph(nodes, edges),
  });
