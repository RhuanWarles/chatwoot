import { ref } from 'vue';
import {
  FIELD_GROUPS,
  STATIC_FIELDS,
  customFieldKey,
  fieldLabelKey,
  isFieldHidden,
} from '../fieldAccess';
import { canResolveConversations, getHiddenFields } from '../permissionsHelper';
import { useFieldAccess } from '../../composables/useFieldAccess';
import messages from '../../i18n/locale/pt_BR/agentMgmt.json';

const mocks = vi.hoisted(() => ({ user: null }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => mocks.user,
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: { value: 1 } }),
}));

const account = extra => ({ id: 1, role: 'agent', ...extra });
const userWith = extra => ({ accounts: [account(extra)] });

describe('isFieldHidden', () => {
  it('hides nothing when no list was set', () => {
    expect(isFieldHidden('contact.email', null)).toBe(false);
    expect(isFieldHidden('contact.email', [])).toBe(false);
    expect(isFieldHidden('contact.email', undefined)).toBe(false);
  });

  it('hides only the fields on the list', () => {
    const hidden = ['contact.email', 'deal.custom.renda'];

    expect(isFieldHidden('contact.email', hidden)).toBe(true);
    expect(isFieldHidden('deal.custom.renda', hidden)).toBe(true);
    expect(isFieldHidden('contact.company', hidden)).toBe(false);
    expect(isFieldHidden('contact.custom.renda', hidden)).toBe(false);
  });

  it('takes the identifier and the WhatsApp username away with the phone number', () => {
    const hidden = ['contact.phone_number'];

    expect(isFieldHidden('contact.identifier', hidden)).toBe(true);
    expect(isFieldHidden('contact.whatsapp', hidden)).toBe(true);
    expect(isFieldHidden('contact.email', hidden)).toBe(false);
  });

  it('lets the phone number stay when only the identifier is hidden', () => {
    expect(isFieldHidden('contact.phone_number', ['contact.identifier'])).toBe(
      false
    );
  });
});

describe('field catalog', () => {
  it('names the custom field of a record', () => {
    expect(customFieldKey('contact', 'cpf')).toBe('contact.custom.cpf');
    expect(customFieldKey('deal', 'renda')).toBe('deal.custom.renda');
  });

  it('has a label for every fixed field, in the language of the settings page', () => {
    const labels = messages.AGENT_MGMT.ACCESS.FIELDS.ITEMS;

    FIELD_GROUPS.forEach(group => {
      expect(
        messages.AGENT_MGMT.ACCESS.FIELDS.GROUPS[group.toUpperCase()]
      ).toBeTruthy();
      STATIC_FIELDS[group].forEach(field => {
        const [, name] = fieldLabelKey(field).split('FIELDS.ITEMS.');
        expect(labels[name]).toBeTruthy();
      });
    });
  });

  it('keeps every fixed field under its own record', () => {
    FIELD_GROUPS.forEach(group => {
      STATIC_FIELDS[group].forEach(field => {
        expect(field.startsWith(`${group}.`)).toBe(true);
      });
    });
  });
});

describe('getHiddenFields', () => {
  it('returns the fields hidden from an agent of the account', () => {
    expect(
      getHiddenFields(userWith({ hidden_fields: ['deal.value'] }), 1)
    ).toEqual(['deal.value']);
  });

  it('returns none when no field was hidden or the user is not loaded', () => {
    expect(getHiddenFields(userWith({ hidden_fields: null }), 1)).toEqual([]);
    expect(getHiddenFields({}, 1)).toEqual([]);
    expect(getHiddenFields(undefined, 1)).toEqual([]);
    expect(
      getHiddenFields(userWith({ hidden_fields: ['deal.value'] }), 2)
    ).toEqual([]);
  });

  it('never hides anything from an administrator', () => {
    const admin = userWith({
      role: 'administrator',
      hidden_fields: ['deal.value'],
    });

    expect(getHiddenFields(admin, 1)).toEqual([]);
  });
});

describe('canResolveConversations', () => {
  it('is allowed unless an administrator switched it off for the agent', () => {
    expect(canResolveConversations(userWith({}), 1)).toBe(true);
    expect(
      canResolveConversations(userWith({ can_resolve_conversations: true }), 1)
    ).toBe(true);
    expect(
      canResolveConversations(userWith({ can_resolve_conversations: false }), 1)
    ).toBe(false);
  });

  it('is allowed while the user is not loaded', () => {
    expect(canResolveConversations({}, 1)).toBe(true);
    expect(canResolveConversations(undefined, 1)).toBe(true);
  });

  it('is always allowed for an administrator', () => {
    const admin = userWith({
      role: 'administrator',
      can_resolve_conversations: false,
    });

    expect(canResolveConversations(admin, 1)).toBe(true);
  });
});

describe('useFieldAccess', () => {
  it('follows the hidden fields and the permission of the signed in agent', () => {
    mocks.user = ref(
      userWith({
        hidden_fields: ['contact.email', 'conversation.custom.origem'],
        can_resolve_conversations: false,
      })
    );
    const { canViewField, canViewCustomField, canResolve } = useFieldAccess();

    expect(canViewField('contact.email')).toBe(false);
    expect(canViewField('contact.company')).toBe(true);
    expect(canViewCustomField('conversation', 'origem')).toBe(false);
    expect(canViewCustomField('contact', 'origem')).toBe(true);
    expect(canResolve.value).toBe(false);
  });

  it('shows everything to a person nothing was switched off for', () => {
    mocks.user = ref(userWith({}));
    const { canViewField, canResolve } = useFieldAccess();

    expect(canViewField('deal.value')).toBe(true);
    expect(canResolve.value).toBe(true);
  });
});
