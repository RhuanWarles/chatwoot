import { effectScope, nextTick, ref } from 'vue';
import { flushPromises } from '@vue/test-utils';
import WhatsappConnectionsAPI from 'dashboard/api/whatsappConnections';
import {
  useWhatsappConnection,
  POLLING_INTERVAL,
  QR_DISPLAY_TIMEOUT,
} from './useWhatsappConnection';

vi.mock('dashboard/api/whatsappConnections', () => ({
  default: { show: vi.fn() },
}));

describe('WhatsApp connection polling', () => {
  let scope;
  let state;
  let identity;

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-20T12:00:00Z'));
    scope = effectScope();
    identity = ref({ accountId: 1, id: 36 });
  });

  afterEach(() => {
    scope.stop();
    vi.useRealTimers();
  });

  it('refreshes every three seconds while connecting and stops on open/connected', async () => {
    WhatsappConnectionsAPI.show
      .mockResolvedValueOnce({
        data: { id: 36, status: 'connecting', qr_code: 'qr-1' },
      })
      .mockResolvedValueOnce({
        data: { id: 36, status: 'connected', phone_number: '5562999999999' },
      });
    scope.run(() => {
      state = useWhatsappConnection(identity);
    });
    await flushPromises();
    expect(state.qrCode.value).toBe('qr-1');
    await vi.advanceTimersByTimeAsync(POLLING_INTERVAL);
    expect(state.connection.value.status).toBe('connected');
    expect(state.qrCode.value).toBeNull();
    await vi.advanceTimersByTimeAsync(POLLING_INTERVAL * 4);
    expect(WhatsappConnectionsAPI.show).toHaveBeenCalledTimes(2);
  });

  it('never overlaps slow requests', async () => {
    WhatsappConnectionsAPI.show.mockReturnValue(new Promise(() => {}));
    scope.run(() => {
      state = useWhatsappConnection(identity);
    });
    state.resume();
    await vi.advanceTimersByTimeAsync(POLLING_INTERVAL * 4);
    expect(WhatsappConnectionsAPI.show).toHaveBeenCalledTimes(1);
  });

  it('expires an unchanged QR locally and only resets its age when the QR changes', async () => {
    WhatsappConnectionsAPI.show.mockResolvedValue({
      data: { id: 36, status: 'connecting', qr_code: 'qr-1' },
    });
    scope.run(() => {
      state = useWhatsappConnection(identity);
    });
    await flushPromises();
    await vi.advanceTimersByTimeAsync(QR_DISPLAY_TIMEOUT);
    expect(state.qrExpired.value).toBe(true);
    state.apply({ id: 36, status: 'connecting', qr_code: 'qr-2' });
    expect(state.qrExpired.value).toBe(false);
  });

  it('stops polling and aborts in-flight requests when the view is disposed', async () => {
    WhatsappConnectionsAPI.show.mockResolvedValue({
      data: { id: 36, status: 'connecting' },
    });
    scope.run(() => {
      state = useWhatsappConnection(identity);
    });
    await flushPromises();
    WhatsappConnectionsAPI.show.mockReturnValue(new Promise(() => {}));
    await vi.advanceTimersByTimeAsync(POLLING_INTERVAL);
    const signal = WhatsappConnectionsAPI.show.mock.calls.at(-1)[1].signal;
    scope.stop();
    expect(signal.aborted).toBe(true);
    await vi.advanceTimersByTimeAsync(POLLING_INTERVAL * 4);
    expect(WhatsappConnectionsAPI.show).toHaveBeenCalledTimes(2);
  });

  it('discards late responses when the account or connection changes', async () => {
    let resolveOld;
    WhatsappConnectionsAPI.show
      .mockImplementationOnce(
        () =>
          new Promise(resolve => {
            resolveOld = resolve;
          })
      )
      .mockResolvedValueOnce({ data: { id: 42, status: 'connected' } });
    scope.run(() => {
      state = useWhatsappConnection(identity);
    });
    const oldSignal = WhatsappConnectionsAPI.show.mock.calls[0][1].signal;
    identity.value = { accountId: 2, id: 42 };
    await nextTick();
    await flushPromises();
    resolveOld({
      data: { id: 36, status: 'connecting', qr_code: 'old-account-qr' },
    });
    await flushPromises();
    expect(oldSignal.aborted).toBe(true);
    expect(state.connection.value.id).toBe(42);
    expect(state.qrCode.value).toBeNull();
  });

  it('stops polling after a provider error and allows an explicit refresh', async () => {
    WhatsappConnectionsAPI.show.mockRejectedValueOnce({
      response: { data: { error: 'Provider unavailable' } },
    });
    scope.run(() => {
      state = useWhatsappConnection(identity);
    });
    await flushPromises();
    expect(state.error.value).toBe('Provider unavailable');
    expect(state.providerUnavailable.value).toBe(true);
    await vi.advanceTimersByTimeAsync(POLLING_INTERVAL * 2);
    expect(WhatsappConnectionsAPI.show).toHaveBeenCalledTimes(1);
    WhatsappConnectionsAPI.show.mockResolvedValue({
      data: { id: 36, status: 'connected' },
    });
    await state.refresh();
    expect(state.error.value).toBe('');
    expect(state.providerUnavailable.value).toBe(false);
    expect(state.connection.value.status).toBe('connected');
  });
});
