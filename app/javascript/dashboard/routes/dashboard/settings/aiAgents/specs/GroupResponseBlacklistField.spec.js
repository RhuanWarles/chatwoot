import { mount } from '@vue/test-utils';
import GroupResponseBlacklistField from '../GroupResponseBlacklistField.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

describe('group response blacklist field', () => {
  it('renders an empty list and adds a formatted phone as canonical digits', async () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: [], enabled: true },
    });
    expect(wrapper.findAll('li')).toHaveLength(0);
    await wrapper.find('input').setValue('+55 (62) 99999-1111');
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([
      ['5562999991111'],
    ]);
    expect(wrapper.find('input').element.value).toBe('');
  });

  it('removes only the selected number', async () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: {
        modelValue: ['5562999991111', '5562988882222'],
        enabled: true,
      },
    });
    await wrapper.find('li button').trigger('click');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([
      ['5562988882222'],
    ]);
  });

  it('rejects duplicates after normalization', async () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: ['5562999991111'], enabled: true },
    });
    await wrapper.find('input').setValue('+55 (62) 99999-1111');
    await wrapper.findAll('button').at(-1).trigger('click');
    expect(wrapper.text()).toContain('AI_AGENTS.GROUP_BLACKLIST_DUPLICATE');
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
  });

  it.each(['', 'hello', '123'])('rejects invalid input %s', async value => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: [], enabled: true },
    });
    await wrapper.find('input').setValue(value);
    await wrapper.find('button').trigger('click');
    expect(wrapper.text()).toContain('AI_AGENTS.GROUP_BLACKLIST_INVALID');
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
  });

  it('keeps the saved list when group replies are switched off and back on', async () => {
    const wrapper = mount(GroupResponseBlacklistField, {
      props: { modelValue: ['5562999991111'], enabled: true },
    });
    await wrapper.setProps({ enabled: false });
    expect(wrapper.find('input').element.disabled).toBe(true);
    expect(wrapper.text()).toContain('5562999991111');
    expect(wrapper.text()).toContain('AI_AGENTS.GROUP_BLACKLIST_DISABLED');
    expect(wrapper.emitted('update:modelValue')).toBeUndefined();
    await wrapper.setProps({ enabled: true });
    expect(wrapper.find('input').element.disabled).toBe(false);
    expect(wrapper.text()).toContain('5562999991111');
  });
});
