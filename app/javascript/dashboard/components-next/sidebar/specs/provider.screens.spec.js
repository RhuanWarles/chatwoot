import { mount } from '@vue/test-utils';
import { defineComponent, h } from 'vue';
import { provideSidebarContext, useSidebarContext } from '../provider';

vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({
    shouldShow: () => true,
    // The CRM is closed for this person.
    hasScreenAccess: path => !path.includes('/crm'),
  }),
}));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: { value: {} },
    updateUISettings: vi.fn(),
  }),
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({
    resolve: to => ({ path: to.path, meta: {} }),
    getRoutes: () => [],
  }),
}));

const readContext = () => {
  let context;
  const Child = defineComponent({
    setup() {
      context = useSidebarContext();
      return () => h('div');
    },
  });
  const Parent = defineComponent({
    setup() {
      provideSidebarContext({});
      return () => h(Child);
    },
  });
  mount(Parent);
  return context;
};

describe('sidebar isAllowed with closed screens', () => {
  it('hides the entries of a screen that was closed', () => {
    const { isAllowed } = readContext();

    expect(isAllowed({ path: '/app/accounts/1/crm/deals' })).toBe(false);
  });

  it('keeps the entries of the other screens', () => {
    const { isAllowed } = readContext();

    expect(isAllowed({ path: '/app/accounts/1/contacts' })).toBe(true);
  });
});
