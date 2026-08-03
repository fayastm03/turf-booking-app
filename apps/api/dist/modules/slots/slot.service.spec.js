"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vitest_1 = require("vitest");
const slot_service_1 = require("./slot.service");
(0, vitest_1.describe)('Slot Service Utility Tests', () => {
    (0, vitest_1.describe)('getDatesInRange', () => {
        (0, vitest_1.it)('generates a single date when start and end are same', () => {
            const dates = (0, slot_service_1.getDatesInRange)('2026-08-01', '2026-08-01');
            (0, vitest_1.expect)(dates).toEqual(['2026-08-01']);
        });
        (0, vitest_1.it)('generates correct date sequence across month boundaries', () => {
            const dates = (0, slot_service_1.getDatesInRange)('2026-07-30', '2026-08-02');
            (0, vitest_1.expect)(dates).toEqual([
                '2026-07-30',
                '2026-07-31',
                '2026-08-01',
                '2026-08-02'
            ]);
        });
        (0, vitest_1.it)('returns empty array if start date is after end date', () => {
            const dates = (0, slot_service_1.getDatesInRange)('2026-08-05', '2026-08-01');
            (0, vitest_1.expect)(dates).toEqual([]);
        });
    });
});
