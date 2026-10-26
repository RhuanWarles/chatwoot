import { describe, expect, it } from 'vitest';
import { nearestDataIndex, tooltipRowsForIndex } from './activityChart';

describe('AI analytics activity chart helpers', () => {
  it('selects the closest date across the full chart area', () => {
    expect(nearestDataIndex([52, 120, 188], 54)).toBe(0);
    expect(nearestDataIndex([52, 120, 188], 139)).toBe(1);
    expect(nearestDataIndex([52, 120, 188], 184)).toBe(2);
  });

  it('keeps the first and last dates selectable', () => {
    expect(nearestDataIndex([52, 120, 188], 0)).toBe(0);
    expect(nearestDataIndex([52, 120, 188], 240)).toBe(2);
  });

  it('includes every dataset, including zero values, in one tooltip', () => {
    const data = {
      series: [
        { label: 'Conversas atendidas', color: 'blue', data: [4] },
        { label: 'Turnos da IA', color: 'iris', data: [105] },
        { label: 'Mensagens enviadas', color: 'teal', data: [0] },
      ],
    };

    expect(tooltipRowsForIndex(data, 0, value => String(value))).toEqual([
      { label: 'Conversas atendidas', color: 'blue', value: '4' },
      { label: 'Turnos da IA', color: 'iris', value: '105' },
      { label: 'Mensagens enviadas', color: 'teal', value: '0' },
    ]);
  });
});
