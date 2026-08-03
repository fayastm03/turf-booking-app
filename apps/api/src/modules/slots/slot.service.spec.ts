import { describe, it, expect } from 'vitest';
import { getDatesInRange } from './slot.service';

describe('Slot Service Utility Tests', () => {
  describe('getDatesInRange', () => {
    it('generates a single date when start and end are same', () => {
      const dates = getDatesInRange('2026-08-01', '2026-08-01');
      expect(dates).toEqual(['2026-08-01']);
    });

    it('generates correct date sequence across month boundaries', () => {
      const dates = getDatesInRange('2026-07-30', '2026-08-02');
      expect(dates).toEqual([
        '2026-07-30',
        '2026-07-31',
        '2026-08-01',
        '2026-08-02'
      ]);
    });

    it('returns empty array if start date is after end date', () => {
      const dates = getDatesInRange('2026-08-05', '2026-08-01');
      expect(dates).toEqual([]);
    });
  });
});
