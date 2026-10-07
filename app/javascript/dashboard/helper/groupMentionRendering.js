import MessageFormatter from 'shared/helpers/MessageFormatter';

export const GROUP_MENTION_PARTICIPANTS = Symbol('groupMentionParticipants');

const RAW_MENTION = /(?<![\w@])@(\d+(?:@(?:lid|s\.whatsapp\.net))?)(?![\w@])/g;
const identityKeys = participant =>
  [participant.lid, participant.jid, participant.phone]
    .filter(Boolean)
    .flatMap(value => [value, value.split('@')[0]]);

const formatPhone = phone => {
  if (/^55\d{10,11}$/.test(phone)) {
    return `+55 ${phone.slice(2, 4)} ${phone.slice(4, -4)}-${phone.slice(-4)}`;
  }
  return `+${phone}`;
};

// The list comes from the authorized Conversation's existing participants API.
// A bare number is matched against identities, never guessed to be a phone.
export const resolveMention = (identifier, participants, mentions = []) => {
  const selected = mentions.find(mention =>
    identityKeys(mention).includes(identifier)
  );
  const keys = selected ? identityKeys(selected) : [identifier];
  const current = participants.find(participant =>
    identityKeys(participant).some(key => keys.includes(key))
  );
  const participant = current || selected;
  if (!participant) return null;

  const name =
    participant.contact_name ||
    participant.whatsapp_name ||
    selected?.display_name;
  return {
    ...participant,
    display_name:
      name || (participant.phone ? formatPhone(participant.phone) : identifier),
  };
};

// Render only Markdown text tokens. Code, URLs and persisted content stay intact.
export const formatGroupMentionContent = (
  content,
  participants,
  mentions = []
) => {
  const markers = new Map();
  const prefix = `CWGM${crypto.randomUUID().replaceAll('-', '')}N`;
  const characters = Array.from(content);
  // Use exact Unicode ranges, not names: two selected people may share a name.
  [...mentions].reverse().forEach((mention, index) => {
    const { start, end, display_name: name } = mention;
    const original = characters.slice(start, end).join('');
    if (original !== `@${name}`) return;
    const participant = resolveMention(
      mention.lid || mention.jid,
      participants,
      [mention]
    );
    if (!participant) return;
    const marker = `${prefix}${index}END`;
    markers.set(marker, { participant, original });
    characters.splice(start, end - start, marker);
  });

  const formatter = new MessageFormatter(characters.join(''));
  const { md } = formatter;
  const pattern = new RegExp(`${prefix}\\d+END|${RAW_MENTION.source}`, 'g');

  md.renderer.rules.text = (tokens, index) => {
    const text = tokens[index].content;
    const preceding = tokens.slice(0, index);
    const linkOpen = preceding.findLastIndex(
      token => token.type === 'link_open'
    );
    const linkClose = preceding.findLastIndex(
      token => token.type === 'link_close'
    );
    if (linkOpen > linkClose) return md.utils.escapeHtml(text);
    let end = 0;
    let result = '';
    Array.from(text.matchAll(pattern)).forEach(match => {
      result += md.utils.escapeHtml(text.slice(end, match.index));
      const participant =
        markers.get(match[0])?.participant ||
        resolveMention(match[0].slice(1), participants, mentions);
      result += participant
        ? `<span class="text-n-blue-11 font-medium">${md.utils.escapeHtml(`@${participant.display_name}`)}</span>`
        : md.utils.escapeHtml(match[0]);
      end = match.index + match[0].length;
    });
    return result + md.utils.escapeHtml(text.slice(end));
  };
  let html = formatter.formattedMessage;
  // Markers inside code are not handled by the text renderer. Restore their
  // original literal spelling rather than displaying an internal marker.
  markers.forEach(({ original }, marker) => {
    html = html.replaceAll(marker, md.utils.escapeHtml(original));
  });
  return html;
};
