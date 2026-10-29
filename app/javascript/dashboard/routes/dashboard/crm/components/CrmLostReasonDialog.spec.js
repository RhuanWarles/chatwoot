import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import messages from 'dashboard/i18n/locale/pt_BR/crm.json';
import CrmLostReasonDialog from './CrmLostReasonDialog.vue';

const DialogStub = {
  name: 'Dialog',
  props: ['title', 'confirmButtonLabel', 'disableConfirmButton'],
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
  template: `<div v-if="visible" class="dialog"><h3>{{ title }}</h3><slot /><button class="confirm" :disabled="disableConfirmButton" @click="$emit('confirm')">{{ confirmButtonLabel }}</button><button class="dismiss" aria-label="dismiss" @click="close" /></div>`,
};
const TextAreaStub = {
  props: ['modelValue', 'label'],
  emits: ['update:modelValue'],
  template:
    '<label>{{ label }}<textarea :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" /></label>',
};

const reasons = [
  { id: 1, name: 'Sem orçamento', active: true },
  { id: 2, name: 'Fechou com concorrente', active: true },
];

const mountDialog = async () => {
  const wrapper = mount(CrmLostReasonDialog, {
    props: { reasons },
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: { Dialog: DialogStub, TextArea: TextAreaStub },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('CrmLostReasonDialog', () => {
  it('opens on mount and lists the reasons to choose from', async () => {
    const wrapper = await mountDialog();

    expect(wrapper.find('.dialog').exists()).toBe(true);
    expect(
      wrapper.findAll('[data-test="lost-reason"]').map(row => row.text())
    ).toEqual(['Sem orçamento', 'Fechou com concorrente']);
  });

  it('does not let the agent confirm before choosing a reason', async () => {
    const wrapper = await mountDialog();

    expect(wrapper.find('.confirm').attributes('disabled')).toBeDefined();
    await wrapper.findAll('input[type="radio"]')[1].setValue();
    expect(wrapper.find('.confirm').attributes('disabled')).toBeUndefined();
  });

  it('confirms with the reason and the trimmed note', async () => {
    const wrapper = await mountDialog();

    await wrapper.findAll('input[type="radio"]')[1].setValue();
    await wrapper.find('textarea').setValue('  Preço menor  ');
    await wrapper.find('.confirm').trigger('click');

    expect(wrapper.emitted('confirm')).toEqual([
      [{ lost_reason_id: 2, lost_note: 'Preço menor' }],
    ]);
    expect(wrapper.emitted('cancel')).toBeUndefined();
  });

  it('sends no note when the field stays empty', async () => {
    const wrapper = await mountDialog();

    await wrapper.findAll('input[type="radio"]')[0].setValue();
    await wrapper.find('.confirm').trigger('click');

    expect(wrapper.emitted('confirm')).toEqual([
      [{ lost_reason_id: 1, lost_note: null }],
    ]);
  });

  it('cancels when the dialog is dismissed', async () => {
    const wrapper = await mountDialog();

    await wrapper.find('.dismiss').trigger('click');

    expect(wrapper.emitted('cancel')).toHaveLength(1);
    expect(wrapper.emitted('confirm')).toBeUndefined();
  });
});
