import { mount } from '@vue/test-utils';
import CrmCurrencyInput from './CrmCurrencyInput.vue';

describe('CrmCurrencyInput', () => {
  it('displays a backend amount in BRL and edits a numeric value', async () => {
    const wrapper = mount(CrmCurrencyInput, {
      props: { modelValue: '2500.00' },
    });
    expect(wrapper.find('input').element.value.replace(/\s/g, ' ')).toBe(
      'R$ 2.500,00'
    );
    await wrapper.find('input').trigger('focus');
    expect(wrapper.find('input').element.value).toBe('2500,00');
    await wrapper.find('input').setValue('5.000,50');
    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([5000.5]);
    await wrapper.setProps({ modelValue: 5000.5 });
    await wrapper.find('input').trigger('blur');
    expect(wrapper.find('input').element.value.replace(/\s/g, ' ')).toBe(
      'R$ 5.000,50'
    );
  });

  it('accepts plain digits without saving the currency symbol', async () => {
    const wrapper = mount(CrmCurrencyInput);
    await wrapper.find('input').setValue('2500');
    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([2500]);
  });

  it('rejects malformed amounts and preserves the previous numeric value', async () => {
    const wrapper = mount(CrmCurrencyInput, { props: { modelValue: 2500 } });
    await wrapper.find('input').setValue('2,500,00');
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
    expect(wrapper.vm.isInvalid).toBe(true);
  });

  it('keeps an optional amount blank and handles zero', async () => {
    const wrapper = mount(CrmCurrencyInput);
    expect(wrapper.find('input').element.value).toBe('');
    await wrapper.find('input').setValue('0');
    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual([0]);
    await wrapper.find('input').setValue('');
    expect(wrapper.emitted('update:modelValue').at(-1)).toEqual(['']);
  });
});
