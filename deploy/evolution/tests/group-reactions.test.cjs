// Run with Evolution's existing node_modules (typescript and long), without networking.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const test = require('node:test');
const ts = require('typescript');
const Long = require('long');
const source = fs.readFileSync(process.env.REACTIONS_ADAPTER_SOURCE, 'utf8');
const body = source.slice(source.indexOf('export class ChatwootService')).replace('export class', 'class');
const compiled = ts.transpileModule(body, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS } }).outputText;
const calls = [];
const logs = [];
class Logger {
  info() {}
  warn(value) { logs.push(value); }
  error(value) { throw new Error(value); }
}
const Adapter = new Function('Logger', 'postgresClient', 'axios', 'Long', `${compiled}; return ChatwootService;`)(Logger, { getChatwootConnection: () => ({}) }, { post: async (...args) => { calls.push(args); } }, Long);
const instance = { instanceName: 'fixture' };
const group = '120363000000001@g.us';

function setup(target = { chatwootConversationId: 36 }) {
  calls.length = 0;
  logs.length = 0;
  const adapter = new Adapter({ waInstances: { fixture: { instanceId: 'instance-fixture' } } }, { get: () => ({ API_KEY: { KEY: 'fixture-secret' } }) }, {
    message: { findFirst: async query => {
      assert.equal(query.where.instanceId, 'instance-fixture');
      assert.equal(query.where.AND[0].key.equals, 'target');
      assert.equal(query.where.AND[1].key.equals, group);
      return target;
    } },
  }, {});
  adapter.provider = {};
  adapter.clientCw = async () => ({});
  adapter.getProvider = async () => ({ url: 'https://fixture.invalid', accountId: 1, token: 'fixture-token' });
  adapter.getConversationMessage = async () => { throw new Error('Reaction became normal content'); };
  adapter.createConversation = async () => { throw new Error('Reaction created conversation'); };
  adapter.createMessage = async () => { throw new Error('Reaction created message'); };
  return adapter;
}

test('real Long-shaped reaction uses a dedicated authenticated request before message creation', async () => {
  const adapter = setup();
  await adapter.eventWhatsapp('messages.upsert', instance, {
    key: { id: 'reaction', remoteJid: group, fromMe: false, participant: '123@lid' },
    pushName: 'Fixture participant',
    message: { reactionMessage: { key: { id: 'target', remoteJid: group, fromMe: true }, text: '👍', senderTimestampMs: { low: -807049093, high: 395, unsigned: true } } },
  });
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], 'https://fixture.invalid/api/v1/accounts/1/conversations/36/reaction_events');
  const event = calls[0][1].reaction;
  assert.equal(event.emoji, '👍');
  assert.equal(event.participant, '123@lid');
  assert.equal(event.target_id, 'target');
  assert.equal(event.timestamp_ms, 1700000000123);
  assert.equal(calls[0][2].headers['X-Evolution-Reaction-Key'], 'fixture-secret');
});

test('empty removal is forwarded and does not create content', async () => {
  await setup().eventWhatsapp('send.message', instance, {
    key: { id: 'remove', remoteJid: group, fromMe: true },
    message: { reactionMessage: { key: { id: 'target' }, text: '', senderTimestampMs: '1700000001123' } },
  });
  assert.equal(calls.length, 1);
  assert.equal(calls[0][1].reaction.emoji, '');
  assert.equal(calls[0][1].reaction.from_me, true);
});

test('unmapped targets never become timeline messages', async () => {
  await setup(null).eventWhatsapp('messages.upsert', instance, {
    key: { id: 'unknown', remoteJid: group, fromMe: false, participant: '123@lid' },
    message: { reactionMessage: { key: { id: 'target' }, text: '❤️', senderTimestampMs: '1700000001123' } },
  });
  assert.equal(calls.length, 0);
  assert.equal(logs.length, 1);
});

test('individual reactions do not enter the normal message/AI path', async () => {
  await setup().eventWhatsapp('messages.upsert', instance, {
    key: { id: 'direct', remoteJid: '5511999999999@s.whatsapp.net', fromMe: false },
    message: { reactionMessage: { key: { id: 'target' }, text: '✅' } },
  });
  assert.equal(calls.length, 0);
});
