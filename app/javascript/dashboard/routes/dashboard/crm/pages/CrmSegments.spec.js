import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';

import { segmentsAPI } from 'dashboard/api/crm';
import messages from 'dashboard/i18n/locale/pt_BR/crm.json';
import Component from './CrmSegments.vue';

vi.mock('dashboard/api/crm', () => ({
  segmentsAPI: {
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
  },
}));

const Button = {
  inheritAttrs: false,
  props: ['label', 'disabled'],
  template:
    '<button v-bind="$attrs" :disabled="disabled"><slot />{{ label }}</button>',
};
const Input = {
  props: ['modelValue', 'label', 'placeholder'],
  emits: ['update:modelValue', 'enter'],
  template:
    '<label><span>{{ label }}</span><input :value="modelValue" :placeholder="placeholder" @input="$emit(\'update:modelValue\', $event.target.value)" @keyup.enter="$emit(\'enter\')" /></label>',
};
const ColorPicker = {
  props: ['modelValue'],
  template: '<span class="color" />',
};

const mountPage = () =>
  mount(Component, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'pt_BR',
          messages: { pt_BR: messages },
        }),
      ],
      stubs: { Button, Input, ColorPicker },
    },
  });

const restaurants = {
  id: 1,
  name: 'Restaurantes',
  color: '#ff0000',
  active: true,
};
const clinics = { id: 2, name: 'Clínicas', color: null, active: true };

beforeEach(() => {
  vi.clearAllMocks();
  segmentsAPI.get.mockResolvedValue({ data: [restaurants, clinics] });
});

describe('CrmSegments', () => {
  it('lists the segments of the account', async () => {
    const wrapper = mountPage();
    await flushPromises();

    const rows = wrapper.findAll('[data-test="segment"]');
    expect(rows.map(row => row.text())).toEqual([
      expect.stringContaining('Restaurantes'),
      expect.stringContaining('Clínicas'),
    ]);
  });

  it('tells how to start when there are none', async () => {
    segmentsAPI.get.mockResolvedValue({ data: [] });
    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain('Nenhum segmento ainda');
  });

  it('registers a new segment and clears the field', async () => {
    segmentsAPI.create.mockResolvedValue({
      data: { id: 3, name: 'Padarias', color: '#1f93ff', active: true },
    });
    const wrapper = mountPage();
    await flushPromises();

    await wrapper
      .find('[data-test="new-segment"] input')
      .setValue('  Padarias ');
    await wrapper.find('[data-test="new-segment"]').trigger('submit');
    await flushPromises();

    expect(segmentsAPI.create).toHaveBeenCalledWith({
      segment: { name: 'Padarias', color: '#1f93ff' },
    });
    expect(wrapper.findAll('[data-test="segment"]')).toHaveLength(3);
    expect(wrapper.find('[data-test="new-segment"] input').element.value).toBe(
      ''
    );
  });

  it('does not send an empty name', async () => {
    const wrapper = mountPage();
    await flushPromises();

    await wrapper.find('[data-test="new-segment"]').trigger('submit');

    expect(segmentsAPI.create).not.toHaveBeenCalled();
  });

  it('shows an error when the server refuses the segment', async () => {
    segmentsAPI.create.mockRejectedValue(new Error('422'));
    const wrapper = mountPage();
    await flushPromises();

    await wrapper
      .find('[data-test="new-segment"] input')
      .setValue('Restaurantes');
    await wrapper.find('[data-test="new-segment"]').trigger('submit');
    await flushPromises();

    expect(wrapper.find('[role="alert"]').text()).toContain(
      'Não foi possível salvar'
    );
    expect(wrapper.findAll('[data-test="segment"]')).toHaveLength(2);
  });

  it('deactivates a segment', async () => {
    segmentsAPI.update.mockResolvedValue({
      data: { ...restaurants, active: false },
    });
    const wrapper = mountPage();
    await flushPromises();

    await wrapper
      .findAll('[data-test="segment"]')[0]
      .findAll('button')
      .find(button => button.text() === 'Desativar')
      .trigger('click');
    await flushPromises();

    expect(segmentsAPI.update).toHaveBeenCalledWith(1, {
      segment: { active: false },
    });
    expect(wrapper.findAll('[data-test="segment"]')[0].text()).toContain(
      'Inativo'
    );
  });

  it('removes an unused segment from the list', async () => {
    segmentsAPI.delete.mockResolvedValue({ data: '' });
    const wrapper = mountPage();
    await flushPromises();

    await wrapper
      .findAll('[data-test="segment"]')[1]
      .findAll('button')
      .at(-1)
      .trigger('click');
    await flushPromises();

    expect(segmentsAPI.delete).toHaveBeenCalledWith(2);
    expect(wrapper.findAll('[data-test="segment"]')).toHaveLength(1);
  });

  it('keeps a segment the server only deactivated, because deals use it', async () => {
    segmentsAPI.delete.mockResolvedValue({
      data: { ...restaurants, active: false },
    });
    const wrapper = mountPage();
    await flushPromises();

    await wrapper
      .findAll('[data-test="segment"]')[0]
      .findAll('button')
      .at(-1)
      .trigger('click');
    await flushPromises();

    expect(wrapper.findAll('[data-test="segment"]')).toHaveLength(2);
    expect(wrapper.findAll('[data-test="segment"]')[0].text()).toContain(
      'Inativo'
    );
  });
});
