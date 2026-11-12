import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import SidebarGroupHeader from '../SidebarGroupHeader.vue';

vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: () => ref(0),
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ resolve: () => ({ href: '/app/ai' }) }),
}));

const mountHeader = props =>
  mount(SidebarGroupHeader, {
    props: { label: 'AI', to: '/ai', icon: 'i-lucide-bot', ...props },
    global: { stubs: { Icon: true } },
  });
const chevron = wrapper => wrapper.find('[data-test="group-chevron"]');

describe('SidebarGroupHeader', () => {
  it('shows a chevron on a group that holds items, pointing down while it is closed', () => {
    const wrapper = mountHeader({ expandable: true });

    expect(chevron(wrapper).exists()).toBe(true);
    expect(chevron(wrapper).classes()).toContain('i-lucide-chevron-down');
    expect(chevron(wrapper).classes()).not.toContain('rotate-180');
    expect(wrapper.attributes('aria-expanded')).toBe('false');
  });

  it('turns the chevron up when the group is expanded', () => {
    const wrapper = mountHeader({ expandable: true, isExpanded: true });

    expect(chevron(wrapper).classes()).toContain('rotate-180');
    expect(wrapper.attributes('aria-expanded')).toBe('true');
  });

  it('counts a group as open when the screen on display is one of its items', () => {
    const wrapper = mountHeader({ expandable: true, hasActiveChild: true });

    expect(chevron(wrapper).classes()).toContain('rotate-180');
    expect(wrapper.attributes('aria-expanded')).toBe('true');
  });

  it('shows no chevron on a plain link', () => {
    const wrapper = mountHeader({ expandable: false });

    expect(chevron(wrapper).exists()).toBe(false);
    expect(wrapper.attributes('aria-expanded')).toBeUndefined();
  });

  it('toggles the group when the chevron is clicked', async () => {
    const wrapper = mountHeader({ expandable: true });

    await chevron(wrapper).trigger('click');

    expect(wrapper.emitted('toggle')).toHaveLength(1);
  });
});
