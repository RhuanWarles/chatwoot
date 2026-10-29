import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';

import { lostReasonsAPI } from 'dashboard/api/crm';
import messages from 'dashboard/i18n/locale/pt_BR/crm.json';
import Component from './CrmLostReasons.vue';

vi.mock('dashboard/api/crm', () => ({
  lostReasonsAPI: {
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
const Draggable = {
  name: 'Draggable',
  props: ['modelValue'],
  emits: ['update:modelValue'],
  template:
    '<ul><slot v-for="(item, index) in modelValue" name="item" :element="item" :index="index" /></ul>',
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
      stubs: { Button, Input, Draggable },
    },
  });

const noBudget = { id: 1, name: 'Sem orçamento', position: 1, active: true };
const competitor = {
  id: 2,
  name: 'Fechou com concorrente',
  position: 2,
  active: true,
};
const noInterest = { id: 3, name: 'Sem interesse', position: 3, active: true };

const rows = wrapper => wrapper.findAll('[data-test="lost-reason"]');
const names = wrapper =>
  rows(wrapper).map(row => row.find('span.flex-1').text());

beforeEach(() => {
  vi.clearAllMocks();
  lostReasonsAPI.get.mockResolvedValue({
    data: [noBudget, competitor, noInterest],
  });
});

describe('CrmLostReasons', () => {
  it('lists the lost reasons of the account in order', async () => {
    const wrapper = mountPage();
    await flushPromises();

    expect(names(wrapper)).toEqual([
      'Sem orçamento',
      'Fechou com concorrente',
      'Sem interesse',
    ]);
  });

  it('tells how to start when there are none', async () => {
    lostReasonsAPI.get.mockResolvedValue({ data: [] });
    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain('Nenhum motivo de perda ainda');
  });

  it('registers a new reason at the end and clears the field', async () => {
    lostReasonsAPI.create.mockResolvedValue({
      data: { id: 4, name: 'Preço', position: 4, active: true },
    });
    const wrapper = mountPage();
    await flushPromises();

    await wrapper
      .find('[data-test="new-lost-reason"] input')
      .setValue(' Preço ');
    await wrapper.find('[data-test="new-lost-reason"]').trigger('submit');
    await flushPromises();

    expect(lostReasonsAPI.create).toHaveBeenCalledWith({
      lost_reason: { name: 'Preço', position: 4 },
    });
    expect(rows(wrapper)).toHaveLength(4);
    expect(
      wrapper.find('[data-test="new-lost-reason"] input').element.value
    ).toBe('');
  });

  it('does not send an empty name', async () => {
    const wrapper = mountPage();
    await flushPromises();

    await wrapper.find('[data-test="new-lost-reason"]').trigger('submit');

    expect(lostReasonsAPI.create).not.toHaveBeenCalled();
  });

  it('shows an error when the server refuses the reason', async () => {
    lostReasonsAPI.create.mockRejectedValue(new Error('422'));
    const wrapper = mountPage();
    await flushPromises();

    await wrapper
      .find('[data-test="new-lost-reason"] input')
      .setValue('Sem orçamento');
    await wrapper.find('[data-test="new-lost-reason"]').trigger('submit');
    await flushPromises();

    expect(wrapper.find('[role="alert"]').text()).toContain(
      'Não foi possível salvar'
    );
    expect(rows(wrapper)).toHaveLength(3);
  });

  it('renames a reason', async () => {
    lostReasonsAPI.update.mockResolvedValue({
      data: { ...noBudget, name: 'Orçamento insuficiente' },
    });
    const wrapper = mountPage();
    await flushPromises();

    await rows(wrapper)[0]
      .find('button[aria-label="Editar motivo"]')
      .trigger('click');
    await rows(wrapper)[0].find('input').setValue('Orçamento insuficiente');
    await rows(wrapper)[0].find('input').trigger('keyup.enter');
    await flushPromises();

    expect(lostReasonsAPI.update).toHaveBeenCalledWith(1, {
      lost_reason: { name: 'Orçamento insuficiente' },
    });
    expect(names(wrapper)[0]).toBe('Orçamento insuficiente');
  });

  it('deactivates a reason', async () => {
    lostReasonsAPI.update.mockResolvedValue({
      data: { ...noBudget, active: false },
    });
    const wrapper = mountPage();
    await flushPromises();

    await rows(wrapper)[0]
      .findAll('button')
      .find(button => button.text() === 'Desativar')
      .trigger('click');
    await flushPromises();

    expect(lostReasonsAPI.update).toHaveBeenCalledWith(1, {
      lost_reason: { active: false },
    });
    expect(rows(wrapper)[0].text()).toContain('Inativo');
  });

  it('removes an unused reason from the list', async () => {
    lostReasonsAPI.delete.mockResolvedValue({ data: '' });
    const wrapper = mountPage();
    await flushPromises();

    await rows(wrapper)[1].find('[data-test="remove"]').trigger('click');
    await flushPromises();

    expect(lostReasonsAPI.delete).toHaveBeenCalledWith(2);
    expect(rows(wrapper)).toHaveLength(2);
  });

  it('keeps a reason the server only deactivated, because deals use it', async () => {
    lostReasonsAPI.delete.mockResolvedValue({
      data: { ...noBudget, active: false },
    });
    const wrapper = mountPage();
    await flushPromises();

    await rows(wrapper)[0].find('[data-test="remove"]').trigger('click');
    await flushPromises();

    expect(rows(wrapper)).toHaveLength(3);
    expect(rows(wrapper)[0].text()).toContain('Inativo');
  });

  it('saves the position of every reason that changed place when dragged', async () => {
    lostReasonsAPI.update.mockImplementation(async (id, body) => ({
      data: { id, ...body.lost_reason },
    }));
    const wrapper = mountPage();
    await flushPromises();

    wrapper
      .findComponent({ name: 'Draggable' })
      .vm.$emit('update:modelValue', [noInterest, noBudget, competitor]);
    await flushPromises();

    expect(lostReasonsAPI.update).toHaveBeenCalledTimes(3);
    expect(lostReasonsAPI.update).toHaveBeenCalledWith(3, {
      lost_reason: { position: 1 },
    });
    expect(lostReasonsAPI.update).toHaveBeenCalledWith(1, {
      lost_reason: { position: 2 },
    });
    expect(lostReasonsAPI.update).toHaveBeenCalledWith(2, {
      lost_reason: { position: 3 },
    });
    expect(names(wrapper)).toEqual([
      'Sem interesse',
      'Sem orçamento',
      'Fechou com concorrente',
    ]);
  });

  it('moves a reason down with the button and saves only the swapped pair', async () => {
    lostReasonsAPI.update.mockResolvedValue({ data: {} });
    const wrapper = mountPage();
    await flushPromises();

    await rows(wrapper)[0].find('[data-test="move-down"]').trigger('click');
    await flushPromises();

    expect(lostReasonsAPI.update).toHaveBeenCalledTimes(2);
    expect(lostReasonsAPI.update).toHaveBeenCalledWith(2, {
      lost_reason: { position: 1 },
    });
    expect(lostReasonsAPI.update).toHaveBeenCalledWith(1, {
      lost_reason: { position: 2 },
    });
  });

  it('restores the old order when the server refuses the new one', async () => {
    lostReasonsAPI.update.mockRejectedValue(new Error('422'));
    const wrapper = mountPage();
    await flushPromises();

    await rows(wrapper)[0].find('[data-test="move-down"]').trigger('click');
    await flushPromises();

    expect(names(wrapper)).toEqual([
      'Sem orçamento',
      'Fechou com concorrente',
      'Sem interesse',
    ]);
    expect(wrapper.find('[role="alert"]').exists()).toBe(true);
  });
});
