import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import CrmPipelines from '../pages/CrmPipelines.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { pipelinesAPI, stagesAPI, dealsAPI } from 'dashboard/api/crm';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';

vi.mock('dashboard/api/crm', () => ({
  pipelinesAPI: {
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    reorderStages: vi.fn(),
  },
  stagesAPI: vi.fn(),
  dealsAPI: { get: vi.fn() },
}));
const api = { create: vi.fn(), update: vi.fn(), delete: vi.fn() };
const pipeline = {
  id: 1,
  name: 'Commercial',
  active: true,
  stages: [
    { id: 10, name: 'Lead' },
    { id: 20, name: 'Proposal' },
  ],
};
const DialogStub = {
  name: 'Dialog',
  props: ['title', 'description', 'showConfirmButton', 'disableConfirmButton'],
  emits: ['confirm', 'close'],
  data: () => ({ visible: false }),
  methods: {
    open() {
      this.visible = true;
    },
    close() {
      this.visible = false;
      this.$emit('close');
    },
  },
  template: `<div v-if="visible" class="dialog"><h3>{{ title }}</h3><p>{{ description }}</p><slot /><button class="confirm" v-if="showConfirmButton !== false" :disabled="disableConfirmButton" @click="$emit('confirm')">{{ title }}</button></div>`,
};
const DraggableStub = {
  name: 'Draggable',
  props: ['modelValue'],
  emits: ['update:modelValue'],
  template:
    '<div><slot v-for="(item, index) in modelValue" name="item" :element="item" :index="index" /></div>',
};
const mountPage = async () => {
  const wrapper = mount(CrmPipelines, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'pt_BR', messages: { pt_BR: pt } }),
      ],
      stubs: { Dialog: DialogStub, Draggable: DraggableStub },
    },
  });
  await flushPromises();
  return wrapper;
};
const click = async (wrapper, text) => {
  await wrapper
    .findAll('button')
    .find(button => button.text() === text)
    .trigger('click');
  await flushPromises();
};
beforeEach(() => {
  vi.clearAllMocks();
  pipelinesAPI.get.mockResolvedValue({ data: structuredClone([pipeline]) });
  pipelinesAPI.create.mockResolvedValue({ data: { id: 2 } });
  pipelinesAPI.update.mockResolvedValue({ data: {} });
  pipelinesAPI.reorderStages.mockResolvedValue({ data: [] });
  dealsAPI.get.mockResolvedValue({ data: [] });
  stagesAPI.mockReturnValue(api);
  api.create.mockResolvedValue({ data: { id: 30 } });
  api.update.mockResolvedValue({ data: {} });
  api.delete.mockResolvedValue({ data: {} });
});
describe('Visual pipeline management', () => {
  it('shows first-pipeline help only when empty', async () => {
    pipelinesAPI.get.mockResolvedValue({ data: [] });
    const wrapper = await mountPage();
    expect(wrapper.text()).toContain(pt.CRM.FIRST_PIPELINE_HELP);
    expect(wrapper.findAll('article')).toHaveLength(0);
  });
  it('lists multiple pipelines with status and stage previews', async () => {
    pipelinesAPI.get.mockResolvedValue({
      data: [pipeline, { ...pipeline, id: 2, name: 'Other', active: false }],
    });
    const wrapper = await mountPage();
    expect(wrapper.findAll('article')).toHaveLength(2);
    expect(wrapper.text()).toContain('Ativo');
    expect(wrapper.text()).toContain('Inativo');
    expect(wrapper.text()).toContain('Proposal');
    expect(wrapper.text()).not.toContain(pt.CRM.FIRST_PIPELINE_HELP);
  });
  it('creates a pipeline and its visual stages through existing APIs', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.NEW_PIPELINE);
    const inputs = wrapper.findAllComponents(Input);
    await inputs[0].find('input').setValue('New');
    await inputs[1].find('input').setValue('First');
    await wrapper.find('.confirm').trigger('click');
    await flushPromises();
    expect(pipelinesAPI.create).toHaveBeenCalledWith({
      pipeline: { name: 'New', active: true },
    });
    expect(api.create).toHaveBeenCalledWith({
      pipeline_stage: { name: 'First' },
    });
    expect(pipelinesAPI.reorderStages).toHaveBeenCalledWith(2, [30]);
  });
  it('adds a stage visually and validates its name', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.EDIT_PIPELINE);
    await click(wrapper, pt.CRM.ADD_STAGE);
    expect(wrapper.findAllComponents(Input)).toHaveLength(4);
    expect(wrapper.find('.confirm').attributes('disabled')).toBeDefined();
    await wrapper
      .findAllComponents(Input)[3]
      .find('input')
      .setValue('New stage');
    await wrapper.find('.confirm').trigger('click');
    await flushPromises();
    expect(api.create).toHaveBeenCalledWith({
      pipeline_stage: { name: 'New stage' },
    });
    expect(pipelinesAPI.reorderStages).toHaveBeenCalledWith(1, [10, 20, 30]);
  });
  it('cancelling confirmed removal does not delete persisted stages', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.EDIT_PIPELINE);
    await wrapper.find('[aria-label="Excluir etapa"]').trigger('click');
    await wrapper.findAll('.dialog')[1].find('.confirm').trigger('click');
    wrapper.findAllComponents(DialogStub)[0].vm.close();
    await flushPromises();
    expect(api.delete).not.toHaveBeenCalled();
    expect(pipelinesAPI.update).not.toHaveBeenCalled();
  });
  it('reactivates inactive pipelines', async () => {
    pipelinesAPI.get.mockResolvedValue({
      data: [{ ...pipeline, active: false }],
    });
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.ACTIVATE);
    expect(pipelinesAPI.update).toHaveBeenCalledWith(1, {
      pipeline: { active: true },
    });
  });
  it('preloads and saves pipeline and stage names', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.EDIT_PIPELINE);
    const inputs = wrapper.findAllComponents(Input);
    expect(inputs[0].props('modelValue')).toBe('Commercial');
    await inputs[0].find('input').setValue('Renamed');
    await inputs[1].find('input').setValue('Qualified');
    await wrapper.find('.confirm').trigger('click');
    await flushPromises();
    expect(pipelinesAPI.update).toHaveBeenCalledWith(1, {
      pipeline: { name: 'Renamed', active: true },
    });
    expect(api.update).toHaveBeenCalledWith(10, {
      pipeline_stage: { name: 'Qualified' },
    });
  });
  it('persists dragged stage order', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.EDIT_PIPELINE);
    const draggable = wrapper.findComponent(DraggableStub);
    draggable.vm.$emit(
      'update:modelValue',
      [...draggable.props('modelValue')].reverse()
    );
    await wrapper.find('.confirm').trigger('click');
    await flushPromises();
    expect(pipelinesAPI.reorderStages).toHaveBeenCalledWith(1, [20, 10]);
  });
  it('confirms empty-stage removal and defers deletion until save', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.EDIT_PIPELINE);
    await wrapper.find('[aria-label="Excluir etapa"]').trigger('click');
    const dialogs = wrapper.findAll('.dialog');
    await dialogs[1].find('.confirm').trigger('click');
    expect(api.delete).not.toHaveBeenCalled();
    await wrapper.find('.confirm').trigger('click');
    await flushPromises();
    expect(api.delete).toHaveBeenCalledWith(10);
    expect(pipelinesAPI.reorderStages).toHaveBeenCalledWith(1, [20]);
  });
  it('blocks occupied-stage deletion and explains where to move deals', async () => {
    dealsAPI.get.mockResolvedValue({
      data: [
        { pipeline_id: 1, pipeline_stage_id: 10 },
        { pipeline_id: 1, pipeline_stage_id: 10 },
        { pipeline_id: 2, pipeline_stage_id: 10 },
      ],
    });
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.EDIT_PIPELINE);
    await wrapper.find('[aria-label="Excluir etapa"]').trigger('click');
    const confirmation = wrapper.findAll('.dialog')[1];
    expect(confirmation.text()).toContain('Esta etapa possui 2');
    expect(confirmation.text()).toContain('Kanban');
    expect(confirmation.find('.confirm').exists()).toBe(false);
    expect(api.delete).not.toHaveBeenCalled();
  });
  it('deactivates a pipeline without deleting stages or deals', async () => {
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.DEACTIVATE);
    expect(pipelinesAPI.update).toHaveBeenCalledWith(1, {
      pipeline: { active: false },
    });
    expect(api.delete).not.toHaveBeenCalled();
  });
  it('keeps the editor open on API failure', async () => {
    pipelinesAPI.update.mockRejectedValueOnce(new Error('failure'));
    const wrapper = await mountPage();
    await click(wrapper, pt.CRM.EDIT_PIPELINE);
    await wrapper.find('.confirm').trigger('click');
    await flushPromises();
    expect(wrapper.find('.dialog').exists()).toBe(true);
    expect(wrapper.find('.dialog').text()).toContain(pt.CRM.SAVE_ERROR);
  });
});
