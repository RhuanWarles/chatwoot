import { config, mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createStore } from 'vuex';
import CrmContactPicker from './CrmContactPicker.vue';
import CrmInlineContactDialog from './CrmInlineContactDialog.vue';
import CrmDeals from '../pages/CrmDeals.vue';
import contactsAPI from 'dashboard/api/contacts';
import { pipelinesAPI, dealsAPI } from 'dashboard/api/crm';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';
import { DuplicateContactException } from 'shared/helpers/CustomErrors';

vi.mock('dashboard/api/contacts', () => ({
  default: { get: vi.fn(), search: vi.fn() },
}));
vi.mock('dashboard/api/crm', () => ({
  pipelinesAPI: { get: vi.fn() },
  dealsAPI: { get: vi.fn(), create: vi.fn(), update: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
}));

const createContact = vi.fn();
const store = createStore({ actions: { 'contacts/create': createContact } });
const CONTACT = {
  id: 30,
  name: 'Jorge',
  phone_number: '+5562991212010',
  email: null,
};
const PIPELINE = {
  id: 1,
  name: 'Pipeline',
  stages: [{ id: 10, name: 'Novo Lead' }],
};

config.global.plugins = [
  createI18n({ legacy: false, locale: 'pt_BR', messages: { pt_BR: pt } }),
  store,
];
config.global.stubs.PhoneNumberInput = {
  props: ['modelValue', 'disabled'],
  emits: ['update:modelValue'],
  template:
    '<input data-phone :value="modelValue" :disabled="disabled" @input="$emit(\'update:modelValue\', $event.target.value)" />',
};
config.global.stubs.Draggable = {
  props: ['modelValue'],
  template:
    '<div><slot v-for="item in modelValue" name="item" :element="item" /></div>',
};
config.global.stubs.RouterLink = { template: '<a><slot /></a>' };

beforeAll(() => {
  HTMLDialogElement.prototype.showModal = function showModal() {
    this.setAttribute('open', '');
  };
  HTMLDialogElement.prototype.close = function close() {
    this.removeAttribute('open');
  };
});
beforeEach(() => {
  contactsAPI.get.mockResolvedValue({ data: { payload: [] } });
  contactsAPI.search.mockResolvedValue({ data: { payload: [] } });
  createContact.mockResolvedValue(CONTACT);
  pipelinesAPI.get.mockResolvedValue({ data: [PIPELINE] });
  dealsAPI.get.mockResolvedValue({ data: [] });
  dealsAPI.create.mockResolvedValue({ data: {} });
});
afterEach(() => {
  document.body.innerHTML = '';
});

describe('CRM inline contact workflow', () => {
  it('keeps edit labels translated and saves the edited numeric BRL amount', async () => {
    dealsAPI.get.mockResolvedValue({
      data: [
        {
          id: 42,
          pipeline_id: 1,
          pipeline_stage_id: 10,
          contact_id: CONTACT.id,
          contact: CONTACT,
          name: 'Existing deal',
          value: '2500.00',
          status: 'open',
          description: '',
        },
      ],
    });
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await wrapper.find('article').trigger('click');
    const form = wrapper.find('form');
    expect(form.text()).toContain('Etapa');
    expect(form.text()).toContain('Contato');
    expect(form.text()).toContain('Salvar alterações');
    const input = form.find('input[inputmode="decimal"]');
    expect(input.element.value.replace(/\s/g, ' ')).toBe('R$ 2.500,00');
    await input.trigger('focus');
    await input.setValue('3.000,25');
    await input.trigger('blur');
    await form.trigger('submit');
    await flushPromises();
    expect(dealsAPI.update).toHaveBeenCalledWith(42, {
      deal: {
        name: 'Existing deal',
        status: 'open',
        description: '',
        contact_id: CONTACT.id,
        pipeline_stage_id: 10,
        value: 3000.25,
      },
    });
    wrapper.unmount();
  });

  it('offers creation only after an empty nonblank search and prefills the exact query', async () => {
    const wrapper = mount(CrmContactPicker);
    await wrapper.find('button').trigger('click');
    await flushPromises();
    expect(wrapper.text()).not.toContain('Criar contato');
    await wrapper.find('input[type="search"]').setValue('Maria Silva');
    await flushPromises();
    expect(wrapper.text()).toContain('Nenhum contato encontrado');
    const action = wrapper
      .findAll('button')
      .find(button => button.text().includes('Criar contato'));
    expect(action.text()).toBe('Criar contato "Maria Silva"');
    await action.trigger('click');
    await flushPromises();
    expect(document.querySelector('dialog[open] input').value).toBe(
      'Maria Silva'
    );
    document.querySelector('dialog[open] button[type="button"]').click();
    await flushPromises();
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
    wrapper.unmount();
  });

  it('keeps a search error distinct from a genuine empty result', async () => {
    const wrapper = mount(CrmContactPicker);
    contactsAPI.search.mockRejectedValue(new Error('offline'));
    await wrapper.find('button').trigger('click');
    await flushPromises();
    await wrapper.find('input[type="search"]').setValue('Jorge');
    await flushPromises();
    expect(wrapper.text()).not.toContain('Criar contato');
    wrapper.unmount();
  });

  it.each([
    ['phone', '+5562991212010', { phoneNumber: '+5562991212010' }],
    ['email', 'jorge@example.com', { email: 'jorge@example.com' }],
  ])(
    'creates with %s through the native store and emits the confirmed contact',
    async (field, value, payload) => {
      const wrapper = mount(CrmInlineContactDialog);
      wrapper.vm.open('Jorge');
      await flushPromises();
      const dialog = document.querySelector('dialog[open]');
      const input = dialog.querySelector(
        field === 'phone' ? '[data-phone]' : 'input[type="email"]'
      );
      input.value = value;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      await flushPromises();
      dialog
        .querySelector('form')
        .dispatchEvent(
          new Event('submit', { bubbles: true, cancelable: true })
        );
      await flushPromises();
      expect(createContact.mock.calls[0][1]).toEqual({
        name: 'Jorge',
        ...payload,
      });
      expect(wrapper.emitted('created')[0]).toEqual([CONTACT]);
      expect(dialog.hasAttribute('open')).toBe(false);
      wrapper.unmount();
    }
  );

  it('preserves input and keeps the dialog open on creation failure', async () => {
    createContact.mockRejectedValue(new Error('offline'));
    const wrapper = mount(CrmInlineContactDialog);
    wrapper.vm.open('Jorge');
    await flushPromises();
    const dialog = document.querySelector('dialog[open]');
    dialog
      .querySelector('form')
      .dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    await flushPromises();
    expect(dialog.hasAttribute('open')).toBe(true);
    expect(dialog.querySelector('input').value).toBe('Jorge');
    expect(dialog.textContent).toContain('Não foi possível criar o contato');
    expect(wrapper.emitted('created')).toBeUndefined();
    wrapper.unmount();
  });

  it('offers an exact existing contact after native duplicate rejection', async () => {
    createContact.mockRejectedValue(
      new DuplicateContactException(['phone_number'])
    );
    contactsAPI.search.mockResolvedValue({ data: { payload: [CONTACT] } });
    const wrapper = mount(CrmInlineContactDialog);
    wrapper.vm.open('Another Name');
    await flushPromises();
    const dialog = document.querySelector('dialog[open]');
    const phone = dialog.querySelector('[data-phone]');
    phone.value = CONTACT.phone_number;
    phone.dispatchEvent(new Event('input', { bubbles: true }));
    await flushPromises();
    dialog
      .querySelector('form')
      .dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    await flushPromises();
    expect(dialog.textContent).toContain('Já existe um contato');
    const select = [...dialog.querySelectorAll('button')].find(button =>
      button.textContent.includes('Selecionar contato existente')
    );
    select.click();
    await flushPromises();
    expect(wrapper.emitted('created')[0]).toEqual([CONTACT]);
    expect(createContact).toHaveBeenCalledTimes(1);
    wrapper.unmount();
  });

  it('validates email and prevents concurrent contact creation', async () => {
    const wrapper = mount(CrmInlineContactDialog);
    wrapper.vm.open('Jorge');
    await flushPromises();
    const dialog = document.querySelector('dialog[open]');
    const email = dialog.querySelector('input[type="email"]');
    email.value = 'invalid';
    email.dispatchEvent(new Event('input', { bubbles: true }));
    await flushPromises();
    dialog
      .querySelector('form')
      .dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    await flushPromises();
    expect(createContact).not.toHaveBeenCalled();
    email.value = '';
    email.dispatchEvent(new Event('input', { bubbles: true }));
    await flushPromises();
    let resolveCreate;
    createContact.mockImplementation(
      () =>
        new Promise(resolve => {
          resolveCreate = resolve;
        })
    );
    const form = dialog.querySelector('form');
    form.dispatchEvent(
      new Event('submit', { bubbles: true, cancelable: true })
    );
    form.dispatchEvent(
      new Event('submit', { bubbles: true, cancelable: true })
    );
    await flushPromises();
    expect(createContact).toHaveBeenCalledTimes(1);
    expect(dialog.textContent).toContain('Criando contato');
    resolveCreate(CONTACT);
    await flushPromises();
    wrapper.unmount();
  });

  it('selects the new contact without creating a deal or losing deal fields', async () => {
    const wrapper = mount(CrmDeals);
    await flushPromises();
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Novo negócio')
      .trigger('click');
    await flushPromises();
    const form = wrapper.find('form');
    const name = form.find('input');
    await name.setValue('Venda Jorge');
    const amount = form.find('input[inputmode="decimal"]');
    await amount.trigger('focus');
    await amount.setValue('5000');
    await amount.trigger('blur');
    const picker = wrapper.findComponent(CrmContactPicker);
    await picker.find('button').trigger('click');
    await flushPromises();
    await picker.find('input[type="search"]').setValue('Jorge');
    await flushPromises();
    await picker
      .findAll('button')
      .find(button => button.text().includes('Criar contato'))
      .trigger('click');
    await flushPromises();
    document
      .querySelector('dialog[open] form')
      .dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
    await flushPromises();
    expect(name.element.value).toBe('Venda Jorge');
    expect(amount.element.value.replace(/\s/g, ' ')).toBe('R$ 5.000,00');
    expect(picker.find('button').text()).toContain('Jorge');
    expect(picker.find('button').text()).toContain('+55 62 99121-2010');
    expect(dealsAPI.create).not.toHaveBeenCalled();
    expect(form.text()).toContain('Etapa');
    expect(form.text()).toContain('Contato');
    expect(form.text()).toContain('Criar negócio');
    await form.trigger('submit');
    await flushPromises();
    expect(dealsAPI.create).toHaveBeenCalledWith({
      deal: {
        name: 'Venda Jorge',
        contact_id: CONTACT.id,
        pipeline_stage_id: 10,
        value: 5000,
        description: '',
        pipeline_id: 1,
      },
    });
    wrapper.unmount();
  });
});
