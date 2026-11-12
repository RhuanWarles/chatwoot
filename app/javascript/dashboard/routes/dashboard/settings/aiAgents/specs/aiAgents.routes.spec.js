import { createMemoryHistory, createRouter } from 'vue-router';
import routes from '../aiAgents.routes';

vi.mock('../Index.vue', () => ({ default: { render: () => null } }));
vi.mock('../AgentDetail.vue', () => ({ default: { render: () => null } }));
vi.mock('../Playground.vue', () => ({ default: { render: () => null } }));
vi.mock('../../SettingsWrapper.vue', () => ({
  default: { render: () => null },
}));

const base = '/app/accounts/48/settings/ai-agents';

const go = async path => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: routes.routes,
  });
  await router.push(path);
  return router.currentRoute.value;
};

it('redirects the old edit URL to the detail, keeping the type', async () => {
  const route = await go(`${base}/3/edit?type=voice`);
  expect(route.fullPath).toBe(`${base}/3?type=voice`);
  expect(route.name).toBe('ai_agent_detail');
});

it('redirects the old new URL to the index', async () => {
  const route = await go(`${base}/new?type=text`);
  expect(route.fullPath).toBe(`${base}?type=text`);
  expect(route.name).toBe('ai_agents_settings');
});

it('puts the open assistant id in the path and passes it as a string prop', async () => {
  const route = await go(`${base}/12?type=text`);
  expect(route.name).toBe('ai_agent_detail');
  expect(route.params).toEqual({ accountId: '48', agentId: '12' });
});

it('keeps the playground on its own route and does not treat it as an assistant id', async () => {
  const route = await go(`${base}/12/playground`);
  expect(route.name).toBe('ai_agent_playground');
  expect(route.meta.fullHeight).toBe(true);
});

it('keeps access restricted to administrators on every route', async () => {
  const names = [
    `${base}?type=text`,
    `${base}/12?type=text`,
    `${base}/12/playground`,
  ];
  const metas = await Promise.all(names.map(path => go(path)));
  metas.forEach(route => {
    expect(route.meta.permissions).toEqual(['administrator']);
  });
});
