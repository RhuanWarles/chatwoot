import { flushPromises } from '@vue/test-utils';
import { lostReasonsAPI } from 'dashboard/api/crm';
import { useLostReasons } from '../useLostReasons';

vi.mock('dashboard/api/crm', () => ({ lostReasonsAPI: { get: vi.fn() } }));

const noBudget = { id: 1, name: 'No budget', active: true };
const competitor = { id: 2, name: 'Went with a competitor', active: true };
const retired = { id: 3, name: 'Old reason', active: false };

describe('useLostReasons', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    lostReasonsAPI.get.mockResolvedValue({
      data: [noBudget, competitor, retired],
    });
  });

  it('keeps only the active reasons for the dialog', async () => {
    const { activeReasons, needsReason, loadLostReasons } = useLostReasons();
    await loadLostReasons();

    expect(activeReasons.value).toEqual([noBudget, competitor]);
    expect(needsReason.value).toBe(true);
  });

  it('does not ask for a reason when none is configured', async () => {
    lostReasonsAPI.get.mockResolvedValue({ data: [retired] });
    const { askLostReason, isLostDialogOpen } = useLostReasons();

    expect(await askLostReason()).toEqual({});
    expect(isLostDialogOpen.value).toBe(false);
  });

  it('marks lost directly when the reasons cannot be loaded', async () => {
    lostReasonsAPI.get.mockRejectedValue(new Error('500'));
    const { askLostReason } = useLostReasons();

    expect(await askLostReason()).toEqual({});
  });

  it('loads the reasons only once', async () => {
    const { askLostReason, cancelLostReason } = useLostReasons();
    askLostReason();
    await flushPromises();
    cancelLostReason();
    askLostReason();
    await flushPromises();

    expect(lostReasonsAPI.get).toHaveBeenCalledTimes(1);
  });

  it('resolves with the chosen reason and closes the dialog', async () => {
    const { askLostReason, confirmLostReason, isLostDialogOpen } =
      useLostReasons();
    const answer = askLostReason();
    await flushPromises();
    expect(isLostDialogOpen.value).toBe(true);

    confirmLostReason({ lost_reason_id: 2, lost_note: 'Cheaper offer' });

    expect(await answer).toEqual({
      lost_reason_id: 2,
      lost_note: 'Cheaper offer',
    });
    expect(isLostDialogOpen.value).toBe(false);
  });

  it('resolves with null when the agent cancels', async () => {
    const { askLostReason, cancelLostReason, isLostDialogOpen } =
      useLostReasons();
    const answer = askLostReason();
    await flushPromises();

    cancelLostReason();

    expect(await answer).toBeNull();
    expect(isLostDialogOpen.value).toBe(false);
  });

  it('finds a reason by id, including inactive ones', async () => {
    const { findLostReason, loadLostReasons } = useLostReasons();
    await loadLostReasons();

    expect(findLostReason(3)).toEqual(retired);
    expect(findLostReason(99)).toBeNull();
  });
});
