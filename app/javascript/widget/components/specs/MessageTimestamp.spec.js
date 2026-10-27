import { mount } from '@vue/test-utils';
import MessageTimestamp from '../MessageTimestamp.vue';

describe('MessageTimestamp', () => {
  it('shows the short time and keeps the full timestamp in the title', () => {
    const wrapper = mount(MessageTimestamp, {
      props: {
        time: Math.floor(new Date('2026-10-27T13:31:00.000Z').getTime() / 1000),
      },
      global: {
        mocks: {
          $i18n: { locale: 'pt_BR' },
        },
      },
    });

    expect(wrapper.find('time').text()).toBe('10:31');
    expect(wrapper.find('time').attributes('title')).toMatch(
      /^27\/10\/2026, 10:31$/
    );
    expect(wrapper.find('time').attributes('datetime')).toBe(
      '2026-10-27T13:31:00.000Z'
    );
  });
});
