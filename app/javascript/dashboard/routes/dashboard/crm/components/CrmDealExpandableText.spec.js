import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import Component from './CrmDealExpandableText.vue';
import messages from 'dashboard/i18n/locale/pt_BR/crm.json';
const create = value =>
  mount(Component, {
    props: { value },
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
it('expands and collapses long text while preserving all its content', async () => {
  const text = 'Cliente demonstrou interesse. '.repeat(20);
  const wrapper = create(text);
  expect(wrapper.find('p').classes()).toContain('line-clamp-3');
  expect(wrapper.find('p').text()).toBe(text.trim());
  await wrapper.find('button').trigger('click');
  expect(wrapper.find('p').classes()).not.toContain('line-clamp-3');
  expect(wrapper.find('button').text()).toBe(messages.CRM.SIDEBAR_LESS);
  await wrapper.find('button').trigger('click');
  expect(wrapper.find('p').classes()).toContain('line-clamp-3');
});
it('shows empty values without an expansion action', () => {
  const wrapper = create('');
  expect(wrapper.text()).toBe(messages.CRM.NOT_SET);
  expect(wrapper.find('button').exists()).toBe(false);
});
it('allows expansion for short text with more than three lines', () => {
  expect(create('A\nB\nC\nD').find('button').exists()).toBe(true);
});
