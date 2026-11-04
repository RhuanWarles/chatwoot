import { mount } from '@vue/test-utils';
import GroupResponseBlacklistField from '../GroupResponseBlacklistField.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

describe('group response blacklist field', () => {
  it('renders an empty list and adds a formatted phone as canonical digits', async () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: [] },
    });
    expect(wrapper.findAll('li')).toHaveLength(0);
    await wrapper.find('input').setValue('+55 (62) 99999-1111');
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([
      ['5562999991111'],
    ]);
    expect(wrapper.find('input').element.value).toBe('');
    expect(wrapper.text()).toContain('AI_AGENTS.GROUP_BLACKLIST_EMPTY');
  });

  it('adds a number when pressing Enter', async () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: [] },
    });
    await wrapper.find('input').setValue('5562999991111');
    await wrapper.find('input').trigger('keyup.enter');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([
      ['5562999991111'],
    ]);
  });

  it('removes only the selected number', async () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: ['5562999991111', '5562988882222'] },
    });
    await wrapper.find('li button').trigger('click');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([
      ['5562988882222'],
    ]);
  });

  it('rejects duplicates after normalization', async () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: ['5562999991111'] },
    });
    await wrapper.find('input').setValue('+55 (62) 99999-1111');
    await wrapper.findAll('button').at(-1).trigger('click');
    expect(wrapper.text()).toContain('AI_AGENTS.GROUP_BLACKLIST_DUPLICATE');
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
  });

  it.each(['', 'hello', '123'])('rejects invalid input %s', async value => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: [] },
    });
    await wrapper.find('input').setValue(value);
    await wrapper.find('button').trigger('click');
    expect(wrapper.text()).toContain('AI_AGENTS.GROUP_BLACKLIST_INVALID');
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
  });

  it('adds a number typed without country code as a Brazilian number', async () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: [] },
    });
    await wrapper.find('input').setValue('62994665004');
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([
      ['5562994665004'],
    ]);
  });

  it('keeps a foreign number typed with + exactly as typed', async () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: [] },
    });
    await wrapper.find('input').setValue('+51 912 345 678');
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([['51912345678']]);
  });

  it('is editable no matter whether group replies are on', () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: ['5562999991111'] },
    });
    expect(wrapper.find('input').element.disabled).toBe(false);
    expect(wrapper.find('li button').element.disabled).toBe(false);
    expect(wrapper.text()).toContain('5562999991111');
  });

  it('locks the field while the form is busy', () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: ['5562999991111'], disabled: true },
    });
    expect(wrapper.find('input').element.disabled).toBe(true);
  });
});
