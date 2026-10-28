import { computed, ref } from 'vue';
import CsNotesAPI from 'dashboard/api/csNotes';

const EMPTY_SETTINGS = Object.freeze({
  loaded: false,
  canAccess: false,
  canManage: false,
  teamId: null,
  fields: [],
});

// Shared by every place that shows the CS notes, so the settings are asked for once.
const settings = ref({ ...EMPTY_SETTINGS });
let pending = null;
let loadedFor = null;

// Same way the API client finds the account: /app/accounts/:id/...
const accountIdFromRoute = () => window.location.pathname.split('/')[3] || '';

const applySettings = (data = {}) => {
  settings.value = {
    loaded: true,
    canAccess: data.can_access === true,
    canManage: data.can_manage === true,
    teamId: data.team_id ?? null,
    fields: data.fields ?? [],
  };
};

export const resetCsNotes = () => {
  pending = null;
  loadedFor = null;
  settings.value = { ...EMPTY_SETTINGS };
};

export const useCsNotes = () => {
  const load = ({ force = false } = {}) => {
    const accountId = accountIdFromRoute();
    // What was loaded for another account says nothing about this one.
    if (loadedFor !== accountId) resetCsNotes();
    if (pending && !force) return pending;

    loadedFor = accountId;
    pending = CsNotesAPI.getSettings()
      .then(({ data }) => applySettings(data))
      // Not knowing is the same as not being allowed: the section stays hidden.
      .catch(() => applySettings({}));
    return pending;
  };

  const saveTeam = async teamId => {
    const { data } = await CsNotesAPI.updateSettings(teamId);
    applySettings(data);
  };

  const addField = async field => {
    const { data } = await CsNotesAPI.createField(field);
    settings.value = {
      ...settings.value,
      fields: [...settings.value.fields, data],
    };
    return data;
  };

  const renameField = async (id, name) => {
    const { data } = await CsNotesAPI.updateField(id, {
      attribute_display_name: name,
    });
    settings.value = {
      ...settings.value,
      fields: settings.value.fields.map(field =>
        field.id === id ? data : field
      ),
    };
  };

  const removeField = async id => {
    await CsNotesAPI.deleteField(id);
    settings.value = {
      ...settings.value,
      fields: settings.value.fields.filter(field => field.id !== id),
    };
  };

  return {
    settings,
    loaded: computed(() => settings.value.loaded),
    canAccess: computed(() => settings.value.canAccess),
    canManage: computed(() => settings.value.canManage),
    teamId: computed(() => settings.value.teamId),
    fields: computed(() => settings.value.fields),
    load,
    saveTeam,
    addField,
    renameField,
    removeField,
  };
};
