import { useCsNotes, resetCsNotes } from '../useCsNotes';
import CsNotesAPI from 'dashboard/api/csNotes';

vi.mock('dashboard/api/csNotes', () => ({
  default: {
    getSettings: vi.fn(),
    updateSettings: vi.fn(),
    createField: vi.fn(),
    updateField: vi.fn(),
    deleteField: vi.fn(),
  },
}));

const field = (id, name = 'Plano') => ({
  id,
  attribute_key: name.toLowerCase(),
  attribute_display_name: name,
  attribute_display_type: 'text',
});

const allowed = {
  can_access: true,
  can_manage: true,
  team_id: 4,
  fields: [field(1)],
};

beforeEach(() => {
  vi.clearAllMocks();
  resetCsNotes();
  window.history.pushState({}, '', '/app/accounts/1/dashboard');
});

describe('useCsNotes', () => {
  it('knows nothing until the settings are loaded', () => {
    const { loaded, canAccess } = useCsNotes();

    expect(loaded.value).toBe(false);
    expect(canAccess.value).toBe(false);
  });

  it('shows what the server allows', async () => {
    CsNotesAPI.getSettings.mockResolvedValue({ data: allowed });
    const { load, loaded, canAccess, canManage, teamId, fields } = useCsNotes();

    await load();

    expect(loaded.value).toBe(true);
    expect(canAccess.value).toBe(true);
    expect(canManage.value).toBe(true);
    expect(teamId.value).toBe(4);
    expect(fields.value).toHaveLength(1);
  });

  it('keeps the section closed when the server says no', async () => {
    CsNotesAPI.getSettings.mockResolvedValue({
      data: { can_access: false, can_manage: false },
    });
    const { load, canAccess, fields } = useCsNotes();

    await load();

    expect(canAccess.value).toBe(false);
    expect(fields.value).toEqual([]);
  });

  it('keeps the section closed when the settings cannot be loaded', async () => {
    CsNotesAPI.getSettings.mockRejectedValue(new Error('500'));
    const { load, loaded, canAccess } = useCsNotes();

    await load();

    expect(loaded.value).toBe(true);
    expect(canAccess.value).toBe(false);
  });

  it('asks the server once, however many places show the section', async () => {
    CsNotesAPI.getSettings.mockResolvedValue({ data: allowed });

    await Promise.all([useCsNotes().load(), useCsNotes().load()]);
    await useCsNotes().load();

    expect(CsNotesAPI.getSettings).toHaveBeenCalledTimes(1);
  });

  it('asks again for another account', async () => {
    CsNotesAPI.getSettings.mockResolvedValue({ data: allowed });
    await useCsNotes().load();

    window.history.pushState({}, '', '/app/accounts/2/dashboard');
    await useCsNotes().load();

    expect(CsNotesAPI.getSettings).toHaveBeenCalledTimes(2);
  });

  it('adds, renames and removes a field', async () => {
    CsNotesAPI.getSettings.mockResolvedValue({ data: allowed });
    const { load, fields, addField, renameField, removeField } = useCsNotes();
    await load();

    CsNotesAPI.createField.mockResolvedValue({ data: field(2, 'Risco') });
    await addField({ attribute_display_name: 'Risco' });
    expect(fields.value.map(item => item.id)).toEqual([1, 2]);

    CsNotesAPI.updateField.mockResolvedValue({ data: field(2, 'Risco atual') });
    await renameField(2, 'Risco atual');
    expect(fields.value[1].attribute_display_name).toBe('Risco atual');
    expect(CsNotesAPI.updateField).toHaveBeenCalledWith(2, {
      attribute_display_name: 'Risco atual',
    });

    CsNotesAPI.deleteField.mockResolvedValue({});
    await removeField(1);
    expect(fields.value.map(item => item.id)).toEqual([2]);
  });

  it('keeps the field when it could not be deleted', async () => {
    CsNotesAPI.getSettings.mockResolvedValue({ data: allowed });
    const { load, fields, removeField } = useCsNotes();
    await load();
    CsNotesAPI.deleteField.mockRejectedValue(new Error('500'));

    await expect(removeField(1)).rejects.toThrow();

    expect(fields.value).toHaveLength(1);
  });

  it('takes the new team into the settings', async () => {
    CsNotesAPI.getSettings.mockResolvedValue({ data: allowed });
    const { load, saveTeam, teamId } = useCsNotes();
    await load();
    CsNotesAPI.updateSettings.mockResolvedValue({
      data: { ...allowed, team_id: 9 },
    });

    await saveTeam(9);

    expect(CsNotesAPI.updateSettings).toHaveBeenCalledWith(9);
    expect(teamId.value).toBe(9);
  });
});
