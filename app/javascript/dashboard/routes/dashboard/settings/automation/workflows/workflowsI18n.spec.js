import { describe, expect, it } from 'vitest';
import en from 'dashboard/i18n/locale/en/automation.json';
import ptBR from 'dashboard/i18n/locale/pt_BR/automation.json';
import { ACTIONS, ACTION_GROUPS, PARAM_TYPES } from './actions';
import {
  OPERATORS,
  STATIC_OPTIONS,
  TRIGGER_EVENTS,
  TRIGGER_GROUPS,
} from './constants';
import { FIELD_GROUPS, STATIC_FIELDS, fieldLabelKey } from './fields';
import { WORKFLOW_TEMPLATES } from './templates';

// Every string of the builder lives under AUTOMATION.WORKFLOWS: this keeps en and pt_BR complete.
const sources = import.meta.glob(['./**/*.vue', './**/*.js'], {
  query: '?raw',
  import: 'default',
  eager: true,
});

const ROOT = 'AUTOMATION.WORKFLOWS';
const lookup = (messages, path) =>
  path.split('.').reduce((node, part) => node?.[part], messages);

const upper = list => list.map(item => String(item).toUpperCase());

const dynamicKeys = () => {
  const keys = [];
  const add = (prefix, parts) =>
    upper(parts).forEach(part => keys.push(`${ROOT}.${prefix}.${part}`));

  add(
    'TRIGGERS',
    TRIGGER_EVENTS.map(item => item.key)
  );
  add(
    'TRIGGER_HINTS',
    TRIGGER_EVENTS.map(item => item.key)
  );
  add('TRIGGER_GROUPS', TRIGGER_GROUPS);
  add(
    'ACTIONS',
    ACTIONS.map(item => item.key)
  );
  add('ACTION_GROUPS', ACTION_GROUPS);
  add(
    'OPERATORS',
    OPERATORS.map(item => item.key)
  );
  add('FIELD_GROUPS', FIELD_GROUPS);
  add('NODE_TYPES', ['trigger', 'condition', 'switch', 'wait', 'action']);
  add('HANDLES', ['true', 'false', 'default', 'out']);
  add('SPECIAL', ['nil', 'last_responding_agent']);
  add('SECTIONS', ['rules', 'workflows']);
  add('TEST.KINDS', ['deal', 'contact', 'conversation']);
  add('HISTORY.RUN_STATUS', ['running', 'waiting', 'completed', 'failed']);
  add('HISTORY.STEP_STATUS', ['ok', 'error', 'skipped', 'waiting']);
  add(
    'INSPECTOR',
    ACTIONS.map(item => item.requires)
      .filter(Boolean)
      .map(item => `requires_${item}`)
  );
  add('VALIDATION', [
    'NO_TRIGGER',
    'TOO_MANY_NODES',
    'CYCLE',
    'UNREACHABLE',
    'EVENT_REQUIRED',
    'CONDITIONS_REQUIRED',
    'CONDITION_INCOMPLETE',
    'SWITCH_FIELD_REQUIRED',
    'SWITCH_CASES_REQUIRED',
    'SWITCH_CASE_VALUE',
    'WAIT_AMOUNT',
    'ACTION_REQUIRED',
    'PARAM_REQUIRED',
    'AT_LEAST_ONE',
    'NODE_HAS_ISSUES',
  ]);

  Object.entries(STATIC_OPTIONS).forEach(([list, values]) =>
    values.forEach(value =>
      keys.push(`${ROOT}.OPTIONS.${list}.${String(value).toUpperCase()}`)
    )
  );
  STATIC_FIELDS.forEach(field => keys.push(fieldLabelKey(field.key)));
  ACTIONS.forEach(action =>
    action.params.forEach(param => {
      keys.push(`${ROOT}.PARAMS.${param.key.toUpperCase()}`);
      if (param.type === PARAM_TYPES.CHECKBOX) {
        keys.push(`${ROOT}.PARAM_HINTS.${param.key.toUpperCase()}`);
      }
    })
  );
  WORKFLOW_TEMPLATES.forEach(template => {
    keys.push(`${ROOT}.TEMPLATES.${template.key.toUpperCase()}.NAME`);
    keys.push(`${ROOT}.TEMPLATES.${template.key.toUpperCase()}.DESCRIPTION`);
  });
  return keys;
};

const literalKeys = () => {
  const found = new Set();
  Object.entries(sources)
    .filter(([path]) => !path.endsWith('.spec.js'))
    .forEach(([, source]) => {
      source
        .match(/AUTOMATION\.WORKFLOWS(?:\.[A-Z0-9_]+)+/g)
        // Keys cut at "_" or "." are prefixes of dynamic keys, covered by dynamicKeys().
        ?.filter(key => !key.endsWith('_'))
        .forEach(key => found.add(key));
    });
  return [...found];
};

const leafPaths = (node, prefix = '') =>
  Object.entries(node).flatMap(([key, value]) =>
    typeof value === 'object'
      ? leafPaths(value, `${prefix}${key}.`)
      : [`${prefix}${key}`]
  );

describe('workflow translations', () => {
  const required = [...new Set([...dynamicKeys(), ...literalKeys()])];

  [
    ['en', en],
    ['pt_BR', ptBR],
  ].forEach(([locale, messages]) => {
    it(`${locale} has every key the builder uses`, () => {
      const missing = required.filter(key => {
        const value = lookup(messages, key);
        // A key that points to a subtree is a prefix of dynamic keys (checked above).
        return value === undefined;
      });
      expect(missing).toEqual([]);
    });
  });

  it('pt_BR has exactly the keys of en', () => {
    const english = leafPaths(en.AUTOMATION.WORKFLOWS).sort();
    const portuguese = leafPaths(ptBR.AUTOMATION.WORKFLOWS).sort();
    expect(portuguese).toEqual(english);
  });

  it('has no empty translations', () => {
    [en, ptBR].forEach(messages => {
      const empty = leafPaths(messages.AUTOMATION.WORKFLOWS).filter(
        path => lookup(messages.AUTOMATION.WORKFLOWS, path) === ''
      );
      expect(empty).toEqual([]);
    });
  });
});
