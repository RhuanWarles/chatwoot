const GROUP_SENDER_COLORS = [
  'text-n-blue-11',
  'text-n-teal-11',
  'text-n-amber-11',
  'text-n-iris-11',
  'text-n-ruby-11',
];

const toDate = timestamp => {
  if (timestamp instanceof Date) return timestamp;

  const numericTimestamp = Number(timestamp);
  if (Number.isFinite(numericTimestamp)) {
    return new Date(
      numericTimestamp < 1_000_000_000_000
        ? numericTimestamp * 1000
        : numericTimestamp
    );
  }

  return new Date(timestamp);
};

const dayKey = date => {
  const value = toDate(date);
  return `${value.getFullYear()}-${value.getMonth()}-${value.getDate()}`;
};

export const formatMessageDaySeparator = (timestamp, locale = 'pt-BR') => {
  const date = toDate(timestamp);
  const today = new Date();
  const dateLocale = locale.replace('_', '-');

  if (dayKey(date) === dayKey(today)) return { key: 'today' };

  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  if (dayKey(date) === dayKey(yesterday)) return { key: 'yesterday' };

  return {
    key: 'date',
    value: new Intl.DateTimeFormat(dateLocale, {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    }).format(date),
  };
};

export const getGroupSenderColor = identifier => {
  const value = String(identifier || 'unknown');
  const hash = [...value].reduce((total, character) => {
    return (total * 31 + character.charCodeAt(0)) >>> 0;
  }, 0);

  return GROUP_SENDER_COLORS[hash % GROUP_SENDER_COLORS.length];
};

const GROUP_SENDER_HEADER = /^\*\*(?<identifier>[^*\n]+?)\s+-\s+(?<name>[^*\n:]+):\*\*/;

export const formatGroupSenderHeader = (formattedContent, content) => {
  const match = content?.match(GROUP_SENDER_HEADER);
  if (!match) return formattedContent;

  const color = getGroupSenderColor(match.groups.identifier.trim());
  return formattedContent.replace(
    /<strong>([^<]+)<\/strong>/,
    `<strong><span class="${color}">$1</span></strong>`
  );
};

