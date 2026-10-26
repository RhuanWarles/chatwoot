import { mount } from '@vue/test-utils';

vi.mock('shared/composables/useBranding', () => ({
  useBranding: () => ({ replaceInstallationName: text => text }),
}));

// Branding reads window.globalConfig when the module is evaluated.
const mountBranding = async (props = {}) => {
  vi.resetModules();
  window.globalConfig = {
    BRAND_NAME: 'Chatwoot',
    LOGO_THUMBNAIL: '/brand-assets/logo_thumbnail.svg',
    WIDGET_BRAND_URL: 'https://www.chatwoot.com',
  };
  const { default: Branding } = await import('../Branding.vue');
  return mount(Branding, {
    props,
    global: {
      mocks: {
        $t: key => key,
        $store: { getters: { 'appConfig/getReferrerHost': 'example.com' } },
      },
    },
  });
};

describe('Branding', () => {
  afterEach(() => {
    delete window.globalConfig;
  });

  describe('with inbox branding', () => {
    it('shows the custom logo, text and link', async () => {
      const wrapper = await mountBranding({
        branding: {
          text: 'Powered by Acme',
          logoUrl: 'https://cdn.acme.com/logo.png',
          url: 'https://acme.com',
        },
      });

      const link = wrapper.find('a');
      expect(link.attributes('href')).toBe('https://acme.com/');
      expect(link.attributes('target')).toBe('_blank');
      expect(link.text()).toBe('Powered by Acme');
      expect(wrapper.find('img').attributes('src')).toBe(
        'https://cdn.acme.com/logo.png'
      );
    });

    it('falls back to the default logo and text without a link', async () => {
      const wrapper = await mountBranding({
        branding: { text: '', logoUrl: '', url: '' },
      });

      expect(wrapper.find('a').exists()).toBe(false);
      expect(wrapper.find('.branding--link').text()).toBe('POWERED_BY');
      expect(wrapper.find('img').attributes('src')).toBe(
        '/brand-assets/logo_thumbnail.svg'
      );
    });

    it('never links to the installation brand site', async () => {
      const wrapper = await mountBranding({
        branding: { text: '', logoUrl: '', url: '' },
      });

      expect(wrapper.html()).not.toContain('chatwoot.com');
    });

    it('does not link urls that are not http(s)', async () => {
      // eslint-disable-next-line no-script-url
      const scriptURL = 'javascript:alert(1)';
      const wrapper = await mountBranding({
        branding: { text: 'Acme', logoUrl: '', url: scriptURL },
      });

      expect(wrapper.find('a').exists()).toBe(false);
    });

    it('shows the custom text even without an installation brand name', async () => {
      vi.resetModules();
      window.globalConfig = {};
      const { default: Branding } = await import('../Branding.vue');
      const wrapper = mount(Branding, {
        props: { branding: { text: 'Powered by Acme', logoUrl: '', url: '' } },
        global: { mocks: { $t: key => key, $store: { getters: {} } } },
      });

      expect(wrapper.find('.branding--link').text()).toBe('Powered by Acme');
      expect(wrapper.find('img').exists()).toBe(false);
    });
  });

  describe('without inbox branding', () => {
    it('keeps the brand link used by the survey page', async () => {
      const wrapper = await mountBranding();

      const href = wrapper.find('a').attributes('href');
      expect(href).toContain('https://www.chatwoot.com');
      expect(href).toContain('utm_source=example.com');
    });
  });

  it('renders nothing when branding is disabled', async () => {
    const wrapper = await mountBranding({
      disableBranding: true,
      branding: { text: 'Powered by Acme', logoUrl: '', url: '' },
    });

    expect(wrapper.find('.branding--link').exists()).toBe(false);
  });
});
