import { frontendURL } from 'dashboard/helper/URLHelper';

export const routes =
  window.globalConfig?.WHATSAPP_CONNECTIONS_ENABLED === true
    ? [
        {
          path: frontendURL('accounts/:accountId/whatsapp'),
          name: 'whatsapp_connections',
          component: () => import('./Index.vue'),
          meta: { permissions: ['administrator'] },
        },
        {
          path: frontendURL('accounts/:accountId/whatsapp/:connectionId'),
          name: 'whatsapp_connection',
          component: () => import('./Index.vue'),
          meta: { permissions: ['administrator'] },
        },
      ]
    : [];
