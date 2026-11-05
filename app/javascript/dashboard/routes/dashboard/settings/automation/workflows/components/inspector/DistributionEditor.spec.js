import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import messages from 'dashboard/i18n/locale/pt_BR/automation.json';
import DistributionEditor from './DistributionEditor.vue';

const ComboBox = {
  props: ['modelValue', 'options'],
  emits: ['update:modelValue'],
  template:
    '<select class="person" :value="modelValue" @change="$emit(\'update:modelValue\', Number($event.target.value))"><option v-for="option in options" :key="option.value" :value="option.value">{{ option.label }}</option></select>',
};
const Input = {
  props: ['modelValue'],
  emits: ['update:modelValue'],
  template:
    '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
};
const Button = {
  inheritAttrs: false,
  props: ['label'],
  template: '<button type="button" v-bind="$attrs">{{ label }}</button>',
};

const agents = [
  { value: 7, label: 'Ana' },
  { value: 8, label: 'Bia' },
  { value: 9, label: 'Caio' },
];

const mountEditor = modelValue =>
  mount(DistributionEditor, {
    props: { modelValue, agents },
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: { ComboBox, Input, Button },
    },
  });

const buttonLabelled = (wrapper, label) =>
  wrapper.findAll('button').find(button => button.text() === label);
const total = wrapper => wrapper.find('[data-test="distribution-total"]');

describe('DistributionEditor', () => {
  it('says what is still to give while the shares are short of 100', () => {
    const wrapper = mountEditor([
      { user_id: 7, percentage: 50 },
      { user_id: 8, percentage: 30 },
    ]);

    expect(total(wrapper).text()).toBe('Faltam 20%');
    expect(total(wrapper).classes()).toContain('text-n-ruby-11');
  });

  it('says how much it is over, and confirms the total when it is 100', async () => {
    const wrapper = mountEditor([
      { user_id: 7, percentage: 80 },
      { user_id: 8, percentage: 40 },
    ]);
    expect(total(wrapper).text()).toBe('Passou 20%');

    await wrapper.setProps({
      modelValue: [
        { user_id: 7, percentage: 60 },
        { user_id: 8, percentage: 40 },
      ],
    });
    expect(total(wrapper).text()).toBe('Total: 100%');
    expect(total(wrapper).classes()).toContain('text-n-teal-11');
  });

  it('adds a person with what is left of the 100%', () => {
    const wrapper = mountEditor([{ user_id: 7, percentage: 60 }]);

    buttonLabelled(wrapper, 'Adicionar pessoa').trigger('click');

    expect(wrapper.emitted('update:modelValue')[0][0]).toEqual([
      { user_id: 7, percentage: 60 },
      { user_id: '', percentage: 40 },
    ]);
  });

  it('adds a person with 1% when nothing is left', () => {
    const wrapper = mountEditor([{ user_id: 7, percentage: 100 }]);

    buttonLabelled(wrapper, 'Adicionar pessoa').trigger('click');

    expect(wrapper.emitted('update:modelValue')[0][0][1]).toEqual({
      user_id: '',
      percentage: 1,
    });
  });

  it('splits the shares evenly between the rows', () => {
    const wrapper = mountEditor([
      { user_id: 7, percentage: 70 },
      { user_id: 8, percentage: 20 },
      { user_id: '', percentage: 5 },
    ]);

    buttonLabelled(wrapper, 'Dividir igualmente').trigger('click');

    expect(
      wrapper.emitted('update:modelValue')[0][0].map(item => item.percentage)
    ).toEqual([34, 33, 33]);
    expect(
      wrapper.emitted('update:modelValue')[0][0].map(item => item.user_id)
    ).toEqual([7, 8, '']);
  });

  it('cannot split an empty list', () => {
    const wrapper = mountEditor([]);

    expect(
      buttonLabelled(wrapper, 'Dividir igualmente').attributes('disabled')
    ).toBeDefined();
  });

  it('does not offer a person who is already in another row', () => {
    const wrapper = mountEditor([
      { user_id: 7, percentage: 50 },
      { user_id: '', percentage: 50 },
    ]);
    const [first, second] = wrapper.findAll('select.person');

    expect(first.findAll('option').map(option => option.text())).toEqual([
      'Ana',
      'Bia',
      'Caio',
    ]);
    expect(second.findAll('option').map(option => option.text())).toEqual([
      'Bia',
      'Caio',
    ]);
  });

  it('changes the person of a row', async () => {
    const wrapper = mountEditor([{ user_id: 7, percentage: 100 }]);

    await wrapper.find('select.person').setValue(9);

    expect(wrapper.emitted('update:modelValue')[0][0]).toEqual([
      { user_id: 9, percentage: 100 },
    ]);
  });

  it('keeps only whole numbers when a percentage is typed', async () => {
    const wrapper = mountEditor([{ user_id: 7, percentage: 100 }]);
    const input = wrapper.find(
      '[data-test="distribution-percentage"] input, input[data-test="distribution-percentage"]'
    );

    await input.setValue('25.7');
    await input.setValue('');

    expect(wrapper.emitted('update:modelValue')[0][0][0].percentage).toBe(25);
    expect(wrapper.emitted('update:modelValue')[1][0][0].percentage).toBe('');
  });

  it('removes a row', async () => {
    const wrapper = mountEditor([
      { user_id: 7, percentage: 60 },
      { user_id: 8, percentage: 40 },
    ]);

    await wrapper.findAll('button[aria-label]')[0].trigger('click');

    expect(wrapper.emitted('update:modelValue')[0][0]).toEqual([
      { user_id: 8, percentage: 40 },
    ]);
  });
});
