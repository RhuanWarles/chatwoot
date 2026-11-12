import { createMemoryHistory, createRouter } from 'vue-router';
import routes from '../aiTools.routes';

vi.mock('../Index.vue', () => ({ default: { render: () => null } }));
vi.mock('../ToolDetailRoute.vue', () => ({ default: { render: () => null } }));
vi.mock('../Logs.vue', () => ({ default: { render: () => null } }));

const base = '/app/accounts/48/settings/ai-tools';

const go = async path => {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: routes.routes,
  });
  await router.push(path);
  return router.currentRoute.value;
};

it('redirects the old edit URL to the detail', async () => {
  const route = await go(`${base}/3/edit`);
  expect(route.fullPath).toBe(`${base}/3`);
  expect(route.name).toBe('ai_tool_detail');
});

it('redirects the old new URL to the index', async () => {
  const route = await go(`${base}/new`);
  expect(route.fullPath).toBe(base);
  expect(route.name).toBe('ai_tools_settings');
});

it('puts the open tool id in the path', async () => {
  const route = await go(`${base}/12`);
  expect(route.name).toBe('ai_tool_detail');
  expect(route.params).toEqual({ accountId: '48', toolId: '12' });
});

it('keeps the logs on their own route instead of reading "logs" as a tool id', async () => {
  const route = await go(`${base}/logs`);
  expect(route.name).toBe('ai_tool_logs');
});

it('keeps access restricted to administrators on every route', async () => {
  const metas = await Promise.all(
    [base, `${base}/12`, `${base}/logs`].map(path => go(path))
  );
  metas.forEach(route => {
    expect(route.meta.permissions).toEqual(['administrator']);
  });
});
