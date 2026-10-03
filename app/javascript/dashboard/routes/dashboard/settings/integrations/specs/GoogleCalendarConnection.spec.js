import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import GoogleCalendarConnection from '../GoogleCalendarConnection.vue';
import CalendarAPI from 'dashboard/api/crmCalendar';
import pt from 'dashboard/i18n/locale/pt_BR/crm.json';
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' }, query: {} }),
}));
vi.mock('dashboard/api/crmCalendar', () => ({
  default: { get: vi.fn(), create: vi.fn(), disconnect: vi.fn() },
}));
const setup = () =>
  mount(GoogleCalendarConnection, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'pt_BR', messages: { pt_BR: pt } }),
      ],
    },
  });
it('explains required OAuth setup and disables connection when missing', async () => {
  CalendarAPI.get.mockResolvedValue({
    data: { connected: false, configured: false },
  });
  const wrapper = setup();
  await flushPromises();
  expect(wrapper.text()).toContain(pt.CRM.CALENDAR_SETUP_REQUIRED);
  expect(wrapper.find('button').attributes('disabled')).toBeDefined();
});
it('shows personal connected email and removes local connection on disconnect', async () => {
  CalendarAPI.get
    .mockResolvedValueOnce({
      data: { connected: true, configured: true, email: 'owner@example.com' },
    })
    .mockResolvedValue({ data: { connected: false, configured: true } });
  CalendarAPI.disconnect.mockResolvedValue({
    data: { revocation_failed: false },
  });
  const wrapper = setup();
  await flushPromises();
  expect(wrapper.text()).toContain('owner@example.com');
  await wrapper
    .findAll('button')
    .find(button => button.text() === pt.CRM.CALENDAR_DISCONNECT)
    .trigger('click');
  await flushPromises();
  expect(CalendarAPI.disconnect).toHaveBeenCalled();
  expect(wrapper.text()).toContain(pt.CRM.CALENDAR_DISCONNECTED_HINT);
});
