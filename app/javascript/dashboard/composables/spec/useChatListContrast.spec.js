import { effectScope, nextTick, ref } from 'vue';
import {
  CONTRAST_BODY_CLASS,
  applyChatListContrast,
  useChatListContrast,
} from '../useChatListContrast';

const state = vi.hoisted(() => ({
  updateUISettings: vi.fn(),
  alert: vi.fn(),
}));
const settings = ref({});

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: settings,
    updateUISettings: state.updateUISettings,
  }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: state.alert }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const scope = effectScope();
const mountComposable = () => scope.run(() => useChatListContrast());

beforeEach(() => {
  vi.clearAllMocks();
  settings.value = {};
  document.body.className = '';
});
afterAll(() => scope.stop());

describe('applyChatListContrast', () => {
  it('adds and removes the class of the body', () => {
    applyChatListContrast(true);
    expect(document.body.classList.contains(CONTRAST_BODY_CLASS)).toBe(true);

    applyChatListContrast(false);
    expect(document.body.classList.contains(CONTRAST_BODY_CLASS)).toBe(false);
  });
});

describe('useChatListContrast', () => {
  it('is off by default and leaves the body alone', () => {
    const { enabled } = mountComposable();

    expect(enabled.value).toBe(false);
    expect(document.body.classList.contains(CONTRAST_BODY_CLASS)).toBe(false);
  });

  it('applies the saved choice right away', () => {
    settings.value = { chat_list_contrast: true };

    const { enabled } = mountComposable();

    expect(enabled.value).toBe(true);
    expect(document.body.classList.contains(CONTRAST_BODY_CLASS)).toBe(true);
  });

  it('follows the setting when it changes', async () => {
    mountComposable();

    settings.value = { chat_list_contrast: true };
    await nextTick();
    expect(document.body.classList.contains(CONTRAST_BODY_CLASS)).toBe(true);

    settings.value = { chat_list_contrast: false };
    await nextTick();
    expect(document.body.classList.contains(CONTRAST_BODY_CLASS)).toBe(false);
  });

  it('saves the choice and tells the user', async () => {
    state.updateUISettings.mockResolvedValue();
    const { setEnabled } = mountComposable();

    await setEnabled(true);

    expect(state.updateUISettings).toHaveBeenCalledWith({
      chat_list_contrast: true,
    });
    expect(state.alert).toHaveBeenCalledWith(
      'PROFILE_SETTINGS.FORM.INTERFACE_SECTION.LIST_CONTRAST.UPDATE_SUCCESS'
    );
  });

  it('warns when the choice could not be saved', async () => {
    state.updateUISettings.mockRejectedValue(new Error('500'));
    const { setEnabled } = mountComposable();

    await setEnabled(true);

    expect(state.alert).toHaveBeenCalledWith(
      'PROFILE_SETTINGS.FORM.INTERFACE_SECTION.LIST_CONTRAST.UPDATE_ERROR'
    );
  });
});
