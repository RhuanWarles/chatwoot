import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';

import messages from 'dashboard/i18n/locale/pt_BR/contact.json';
import CsFieldInput from '../CsFieldInput.vue';

const field = (type, extra = {}) => ({
  id: 1,
  attribute_key: 'campo',
  attribute_display_name: 'Campo',
  attribute_display_type: type,
  ...extra,
});

const mountInput = (props = {}) =>
  mount(CsFieldInput, {
    props: { field: field('text'), modelValue: '', ...props },
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
    },
  });

describe('CsFieldInput', () => {
  it('sends the text when the person leaves the field', async () => {
    const wrapper = mountInput();
    const textarea = wrapper.find('textarea');

    await textarea.setValue('Cliente quer renovar');
    expect(wrapper.emitted('commit')).toBeUndefined();

    await textarea.trigger('blur');
    expect(wrapper.emitted('commit')[0]).toEqual(['Cliente quer renovar']);
  });

  it('sends nothing when the text did not change', async () => {
    const wrapper = mountInput({ modelValue: 'Pro' });

    await wrapper.find('textarea').trigger('blur');

    expect(wrapper.emitted('commit')).toBeUndefined();
  });

  it('sends an empty text to clear a field that had one', async () => {
    const wrapper = mountInput({ modelValue: 'Pro' });

    await wrapper.find('textarea').setValue('');
    await wrapper.find('textarea').trigger('blur');

    expect(wrapper.emitted('commit')[0]).toEqual(['']);
  });

  it('uses a number input for numbers, money and percentages', () => {
    ['number', 'currency', 'percent'].forEach(type => {
      const wrapper = mountInput({ field: field(type) });

      expect(wrapper.find('input').attributes('type')).toBe('number');
    });
  });

  it('uses the right input for links and dates', () => {
    expect(
      mountInput({ field: field('link') })
        .find('input')
        .attributes('type')
    ).toBe('url');
    expect(
      mountInput({ field: field('date') })
        .find('input')
        .attributes('type')
    ).toBe('date');
  });

  it('offers the options of a list, plus an empty one, and sends the chosen', async () => {
    const wrapper = mountInput({
      field: field('list', { attribute_values: ['Baixo', 'Alto'] }),
    });

    const options = wrapper.findAll('option').map(option => option.text());
    expect(options).toEqual([messages.CS_NOTES.NO_VALUE, 'Baixo', 'Alto']);

    await wrapper.find('select').setValue('Alto');
    expect(wrapper.emitted('commit')[0]).toEqual(['Alto']);
  });

  it('sends yes or no for a checkbox', async () => {
    const wrapper = mountInput({ field: field('checkbox'), modelValue: false });

    await wrapper.find('input[type="checkbox"]').setValue(true);
    expect(wrapper.emitted('commit')[0]).toEqual([true]);

    await wrapper.setProps({ modelValue: true });
    await wrapper.find('input[type="checkbox"]').setValue(false);
    expect(wrapper.emitted('commit')[1]).toEqual([false]);
  });

  it('follows the value when it changes from outside', async () => {
    const wrapper = mountInput({ modelValue: 'Pro' });

    await wrapper.setProps({ modelValue: 'Free' });

    expect(wrapper.find('textarea').element.value).toBe('Free');
  });
});
