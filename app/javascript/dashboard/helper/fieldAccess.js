// Fields an administrator can hide from an agent. The dashboard stops showing them; the API still returns them.
// Keep in sync with AccountUser::HIDDEN_FIELDS. The custom fields of each record are `<record>.custom.<key>`.
export const FIELD_GROUPS = ['contact', 'conversation', 'deal'];

export const STATIC_FIELDS = {
  contact: [
    'contact.email',
    'contact.phone_number',
    'contact.whatsapp',
    'contact.identifier',
    'contact.company',
    'contact.location',
    'contact.social_profiles',
    'contact.bio',
  ],
  conversation: [
    'conversation.initiated_at',
    'conversation.browser_language',
    'conversation.referer',
    'conversation.browser',
    'conversation.platform',
    'conversation.ip_address',
  ],
  deal: ['deal.value', 'deal.description', 'deal.owner'],
};

export const customFieldKey = (record, key) => `${record}.custom.${key}`;

export const fieldLabelKey = field =>
  `AGENT_MGMT.ACCESS.FIELDS.ITEMS.${field.replace('.', '_').toUpperCase()}`;

// These show the phone number too (the identifier of a WhatsApp contact is its number), so they go with it.
const HIDDEN_WITH = {
  'contact.identifier': 'contact.phone_number',
  'contact.whatsapp': 'contact.phone_number',
};

// `hiddenFields` is empty when the person sees every field.
export const isFieldHidden = (field, hiddenFields) => {
  if (!Array.isArray(hiddenFields) || !hiddenFields.length) return false;
  return (
    hiddenFields.includes(field) || hiddenFields.includes(HIDDEN_WITH[field])
  );
};
