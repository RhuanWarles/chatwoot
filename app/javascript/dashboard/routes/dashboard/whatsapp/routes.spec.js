describe('optional WhatsApp routes and global configuration', () => {
  const originalConfig = window.globalConfig;

  afterEach(() => {
    window.globalConfig = originalConfig;
    vi.resetModules();
  });

  it('registers no screens without the backend availability flag', async () => {
    window.globalConfig = {};
    const { routes } = await import('./routes');
    expect(routes).toEqual([]);
  });

  it('registers no screens when availability is false', async () => {
    window.globalConfig = { WHATSAPP_CONNECTIONS_ENABLED: false };
    const { routes } = await import('./routes');
    expect(routes).toEqual([]);
  });

  it('registers account-scoped, administrator-only screens when enabled', async () => {
    window.globalConfig = { WHATSAPP_CONNECTIONS_ENABLED: true };
    const { routes } = await import('./routes');
    expect(routes.map(route => route.name)).toEqual([
      'whatsapp_connections',
      'whatsapp_connection',
    ]);
    expect(
      routes.every(
        route =>
          route.path.includes(':accountId') &&
          route.meta.permissions.includes('administrator')
      )
    ).toBe(true);
  });

  it('defaults the sidebar availability getter to false', async () => {
    window.globalConfig = {};
    const { default: config } = await import('shared/store/globalConfig');
    expect(config.getters.isWhatsappConnectionsEnabled(config.state)).toBe(
      false
    );
  });

  it('only stores a feature boolean and never an Evolution key or URL', async () => {
    window.globalConfig = { WHATSAPP_CONNECTIONS_ENABLED: true };
    const { default: config } = await import('shared/store/globalConfig');
    expect(config.getters.isWhatsappConnectionsEnabled(config.state)).toBe(
      true
    );
    expect(config.state).not.toHaveProperty('EVOLUTION_API_KEY');
    expect(config.state).not.toHaveProperty('EVOLUTION_API_URL');
  });
});
