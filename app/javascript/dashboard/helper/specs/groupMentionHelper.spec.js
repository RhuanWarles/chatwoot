import {
  messageSchema,
  MessageMarkdownSerializer,
  MessageMarkdownTransformer,
  EditorState,
} from '@chatwoot/prosemirror-schema';
import {
  withGroupMentionSchema,
  withGroupMentionSerializer,
  parseGroupMentionDraft,
  groupMentionPayload,
} from '../groupMentionHelper';

const fernando = {
  lid: '247613823709228@lid',
  jid: '5519994212713@s.whatsapp.net',
  phone: '5519994212713',
  display_name: 'Fernando Murilo',
};
const fabiana = {
  lid: '247613823709229@lid',
  jid: '5519994212714@s.whatsapp.net',
  phone: '5519994212714',
  display_name: 'Fabiana Moretti',
};

describe('group mention identity in the composer', () => {
  const schema = withGroupMentionSchema(messageSchema);
  const serializer = withGroupMentionSerializer(MessageMarkdownSerializer);

  it('sends a selected participant as readable text and structured metadata', () => {
    const doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.text('Oi '),
        schema.nodes.groupMention.create({ participant: fernando }),
      ]),
    ]);
    expect(groupMentionPayload(serializer.serialize(doc))).toEqual({
      message: 'Oi @Fernando Murilo',
      mentions: [{ ...fernando, start: 3, end: 19 }],
    });
  });

  it('preserves two different identities even when their names are identical', () => {
    const second = { ...fabiana, display_name: fernando.display_name };
    const doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.nodes.groupMention.create({ participant: fernando }),
        schema.text(' e '),
        schema.nodes.groupMention.create({ participant: second }),
      ]),
    ]);
    const { mentions } = groupMentionPayload(serializer.serialize(doc));
    expect(mentions.map(mention => mention.lid)).toEqual([
      fernando.lid,
      second.lid,
    ]);
    expect(mentions[1].start).toBe(19);
  });

  it('removes metadata when the mention atom is deleted', () => {
    const state = EditorState.create({
      schema,
      doc: schema.node('doc', null, [
        schema.node('paragraph', null, [
          schema.nodes.groupMention.create({ participant: fernando }),
        ]),
      ]),
    });
    const updated = state.apply(state.tr.delete(1, 2));
    expect(
      groupMentionPayload(serializer.serialize(updated.doc)).mentions
    ).toEqual([]);
  });

  it('does not infer a mention from a manually typed name or phone', () => {
    expect(groupMentionPayload('Oi @Fernando Murilo e @5519994212713')).toEqual(
      {
        message: 'Oi @Fernando Murilo e @5519994212713',
        mentions: [],
      }
    );
  });

  it('restores the selected identity when a draft is loaded', () => {
    const doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.nodes.groupMention.create({ participant: fernando }),
      ]),
    ]);
    const draft = serializer.serialize(doc);
    const restored = parseGroupMentionDraft(draft, schema, text =>
      new MessageMarkdownTransformer(schema).parse(text)
    );
    expect(restored.firstChild.firstChild.type.name).toBe('groupMention');
    expect(restored.firstChild.firstChild.attrs.participant).toEqual(fernando);
    expect(serializer.serialize(restored)).toBe(draft);
  });

  it('counts an emoji before a mention as one Unicode code point', () => {
    const doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.text('👋 '),
        schema.nodes.groupMention.create({ participant: fernando }),
      ]),
    ]);
    const { mentions } = groupMentionPayload(serializer.serialize(doc));
    expect(mentions[0]).toMatchObject({ start: 2, end: 18 });
  });

  it('supports a participant that only has a phone JID', () => {
    const participant = { ...fernando, lid: null };
    const doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.nodes.groupMention.create({ participant }),
      ]),
    ]);
    expect(groupMentionPayload(serializer.serialize(doc)).mentions[0].jid).toBe(
      fernando.jid
    );
  });

  it('preserves special characters in a selected display name', () => {
    const participant = {
      ...fernando,
      display_name: 'João [Comercial] (Sul) & Cia',
    };
    const doc = schema.node('doc', null, [
      schema.node('paragraph', null, [
        schema.nodes.groupMention.create({ participant }),
      ]),
    ]);
    const draft = serializer.serialize(doc);
    const restored = parseGroupMentionDraft(draft, schema, text =>
      new MessageMarkdownTransformer(schema).parse(text)
    );
    expect(groupMentionPayload(serializer.serialize(restored)).message).toBe(
      `@${participant.display_name}`
    );
  });

  it('keeps normal Markdown serialization unchanged', () => {
    const doc = new MessageMarkdownTransformer(schema).parse(
      'Oi **cliente**\n\nTudo bem?'
    );
    expect(serializer.serialize(doc)).toBe(
      MessageMarkdownSerializer.serialize(doc)
    );
    expect(groupMentionPayload(serializer.serialize(doc)).mentions).toEqual([]);
  });
});
