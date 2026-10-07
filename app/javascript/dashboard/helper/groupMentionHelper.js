const DRAFT_MENTION =
  /\[((?:\\.|[^\]\\])*)\]\(mention:\/\/group\/([\w%.~-]+)\)/g;
const IDENTIFIER = /^\d+@(lid|s\.whatsapp\.net)$/;

// An inline atom keeps the selected identity through editing, undo, and drafts.
export const withGroupMentionSchema = schema => {
  const Schema = schema.constructor;
  return new Schema({
    nodes: schema.spec.nodes.addBefore('text', 'groupMention', {
      inline: true,
      group: 'inline',
      atom: true,
      selectable: false,
      attrs: { participant: {} },
      leafText: node => `@${node.attrs.participant.display_name}`,
      toDOM: node => [
        'span',
        { class: 'prosemirror-mention-node' },
        `@${node.attrs.participant.display_name}`,
      ],
    }),
    marks: schema.spec.marks,
  });
};

export const withGroupMentionSerializer = serializer => {
  const Serializer = serializer.constructor;
  return new Serializer(
    {
      ...serializer.nodes,
      groupMention(state, node) {
        const participant = node.attrs.participant;
        const label = participant.display_name.replace(/[\\[\]]/g, '\\$&');
        const identity = encodeURIComponent(
          JSON.stringify(participant)
        ).replace(
          /[!'()*]/g,
          char => `%${char.charCodeAt(0).toString(16).toUpperCase()}`
        );
        state.write(`[@${label}](mention://group/${identity})`);
      },
    },
    serializer.marks
  );
};

const decodeParticipant = encoded => {
  try {
    const participant = JSON.parse(decodeURIComponent(encoded));
    if (
      typeof participant.display_name !== 'string' ||
      !participant.display_name ||
      !IDENTIFIER.test(participant.lid || participant.jid)
    ) {
      return null;
    }
    return participant;
  } catch {
    return null;
  }
};

// Replace draft tokens before Markdown parsing, then restore them as atoms.
// The parser never needs to interpret a raw LID/JID as a visible link.
export const parseGroupMentionDraft = (content, schema, parse) => {
  const participants = [];
  const tokenPrefix = `CWGROUP${crypto.randomUUID().replaceAll('-', '')}`;
  const prepared = content.replace(DRAFT_MENTION, (match, label, encoded) => {
    const participant = decodeParticipant(encoded);
    if (!participant) return match;
    participants.push(participant);
    return `${tokenPrefix}N${participants.length - 1}END`;
  });
  const doc = parse(prepared);
  if (!participants.length) return doc;

  const tokenPattern = new RegExp(`${tokenPrefix}N(\\d+)END`, 'g');
  const restore = node => {
    if (node.type === 'text') {
      const pieces = [];
      let end = 0;
      for (const match of node.text.matchAll(tokenPattern)) {
        if (match.index > end) {
          pieces.push({ ...node, text: node.text.slice(end, match.index) });
        }
        pieces.push({
          type: 'groupMention',
          attrs: { participant: participants[Number(match[1])] },
          marks: node.marks,
        });
        end = match.index + match[0].length;
      }
      if (end < node.text.length) {
        pieces.push({ ...node, text: node.text.slice(end) });
      }
      return pieces;
    }
    return [{ ...node, content: node.content?.flatMap(restore) }];
  };
  return schema.nodeFromJSON(restore(doc.toJSON())[0]);
};

// Offsets count Unicode code points (Ruby string offsets), not UTF-16 units.
export const groupMentionPayload = draft => {
  const mentions = [];
  let message = '';
  let previousEnd = 0;
  for (const match of draft.matchAll(DRAFT_MENTION)) {
    const participant = decodeParticipant(match[2]);
    if (!participant) continue;
    message += draft.slice(previousEnd, match.index);
    const text = `@${participant.display_name}`;
    const start = Array.from(message).length;
    message += text;
    mentions.push({
      ...participant,
      start,
      end: start + Array.from(text).length,
    });
    previousEnd = match.index + match[0].length;
  }
  message += draft.slice(previousEnd);
  return { message, mentions };
};
