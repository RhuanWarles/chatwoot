import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';

import { autoCardSettingsAPI } from 'dashboard/api/crm';
import { useAlert } from 'dashboard/composables';
import messages from 'dashboard/i18n/locale/pt_BR/crm.json';
import Component from './CrmAutoCardSettings.vue';

vi.mock('dashboard/api/crm', () => ({
  autoCardSettingsAPI: { getSettings: vi.fn(), updateSettings: vi.fn() },
}));
vi.mock('dashboard/composables', async importOriginal => ({
  ...(await importOriginal()),
  useAlert: vi.fn(),
}));

const Button = {
  inheritAttrs: false,
  props: ['label', 'disabled'],
  template:
    '<button v-bind="$attrs" :disabled="disabled"><slot />{{ label }}</button>',
};
const Switch = {
  props: ['modelValue', 'disabled'],
  emits: ['update:modelValue'],
  template:
    '<input type="checkbox" data-test="enabled" :checked="modelValue" :disabled="disabled" @change="$emit(\'update:modelValue\', $event.target.checked)" />',
};
const ComboBox = {
  props: ['modelValue', 'options', 'disabled'],
  emits: ['update:modelValue'],
  template:
    '<select :value="modelValue" :disabled="disabled" @change="$emit(\'update:modelValue\', $event.target.selectedOptions[0].dataset.value === \'\' ? \'\' : Number($event.target.selectedOptions[0].dataset.value))"><option v-for="option in options" :key="option.value" :data-value="option.value" :value="option.value">{{ option.label }}</option></select>',
};

const pipelines = [
  {
    id: 1,
    name: 'Comercial',
    active: true,
    stages: [
      { id: 10, name: 'Novo' },
      { id: 11, name: 'Qualificado' },
    ],
  },
  { id: 2, name: 'Antigo', active: false, stages: [{ id: 20, name: 'Fim' }] },
];

const mountSettings = () =>
  mount(Component, {
    props: { pipelines },
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: { Button, Switch, ComboBox },
    },
  });

const settings = { enabled: true, pipeline_id: null, stage_id: null };

beforeEach(() => {
  vi.clearAllMocks();
  autoCardSettingsAPI.getSettings.mockResolvedValue({ data: settings });
  autoCardSettingsAPI.updateSettings.mockResolvedValue({ data: settings });
});

describe('CrmAutoCardSettings', () => {
  it('loads the current settings', async () => {
    autoCardSettingsAPI.getSettings.mockResolvedValue({
      data: { enabled: true, pipeline_id: 1, stage_id: 11 },
    });
    const wrapper = mountSettings();
    await flushPromises();

    const [pipelineSelect, stageSelect] = wrapper.findAll('select');
    expect(pipelineSelect.element.value).toBe('1');
    expect(stageSelect.element.value).toBe('11');
  });

  it('only offers active pipelines and the stages of the chosen one', async () => {
    autoCardSettingsAPI.getSettings.mockResolvedValue({
      data: { enabled: true, pipeline_id: 1, stage_id: null },
    });
    const wrapper = mountSettings();
    await flushPromises();

    const [pipelineSelect, stageSelect] = wrapper.findAll('select');
    expect(pipelineSelect.findAll('option').map(item => item.text())).toEqual([
      'Automático (funil ativo mais antigo)',
      'Comercial',
    ]);
    expect(stageSelect.findAll('option').map(item => item.text())).toEqual([
      'Primeira etapa',
      'Novo',
      'Qualificado',
    ]);
  });

  it('hides the stage while the pipeline is automatic', async () => {
    const wrapper = mountSettings();
    await flushPromises();

    expect(wrapper.findAll('select')).toHaveLength(1);
  });

  it('saves the choice with empty values as null and shows the confirmation', async () => {
    const wrapper = mountSettings();
    await flushPromises();

    await wrapper.find('select').setValue(1);
    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(autoCardSettingsAPI.updateSettings).toHaveBeenCalledWith({
      enabled: true,
      pipeline_id: 1,
      stage_id: null,
    });
    expect(useAlert).toHaveBeenCalledWith(
      'Configuração de cards automáticos salva.'
    );
  });

  it('can be turned off', async () => {
    const wrapper = mountSettings();
    await flushPromises();

    await wrapper.find('[data-test="enabled"]').setValue(false);
    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(autoCardSettingsAPI.updateSettings).toHaveBeenCalledWith(
      expect.objectContaining({ enabled: false })
    );
  });

  it('shows the message of the server when the choice is refused', async () => {
    autoCardSettingsAPI.updateSettings.mockRejectedValue({
      response: { data: { message: 'A etapa não pertence ao funil' } },
    });
    const wrapper = mountSettings();
    await flushPromises();

    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith('A etapa não pertence ao funil');
  });
});
