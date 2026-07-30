"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDatesInRange = getDatesInRange;
exports.generateSlotsForTurf = generateSlotsForTurf;
exports.generateSlotsForAllActiveTurfs = generateSlotsForAllActiveTurfs;
exports.blockSlots = blockSlots;
const prisma_1 = require("../../db/prisma");
const client_1 = require("@prisma/client");
function getDatesInRange(startDateStr, endDateStr) {
    const dates = [];
    const current = new Date(`${startDateStr}T00:00:00Z`);
    const end = new Date(`${endDateStr}T00:00:00Z`);
    while (current <= end) {
        dates.push(current.toISOString().split('T')[0]);
        current.setUTCDate(current.getUTCDate() + 1);
    }
    return dates;
}
async function generateSlotsForTurf(turfId, startDateStr, endDateStr) {
    const courts = await prisma_1.prisma.court.findMany({
        where: { turfId, isActive: true },
        include: { slotTemplates: true },
    });
    const dates = getDatesInRange(startDateStr, endDateStr);
    const slotsToCreate = [];
    for (const court of courts) {
        for (const dateStr of dates) {
            const dateObj = new Date(`${dateStr}T00:00:00Z`);
            const dayOfWeek = dateObj.getUTCDay();
            // Filter templates for this day of week
            const templatesForDay = court.slotTemplates.filter((t) => t.dayOfWeek === dayOfWeek);
            for (const template of templatesForDay) {
                const price = template.priceOverride !== null ? template.priceOverride : court.pricePerHour;
                slotsToCreate.push({
                    courtId: court.id,
                    date: dateStr,
                    startTime: template.startTime,
                    endTime: template.endTime,
                    price,
                    status: client_1.SlotStatus.AVAILABLE,
                });
            }
        }
    }
    if (slotsToCreate.length === 0)
        return 0;
    // Bulk create slots and skip duplicate conflicts
    const result = await prisma_1.prisma.slot.createMany({
        data: slotsToCreate,
        skipDuplicates: true,
    });
    return result.count;
}
async function generateSlotsForAllActiveTurfs(daysCount = 30) {
    const activeTurfs = await prisma_1.prisma.turf.findMany({
        where: { status: 'ACTIVE' },
    });
    const today = new Date();
    const startDateStr = today.toISOString().split('T')[0];
    const endDate = new Date();
    endDate.setDate(today.getDate() + daysCount - 1);
    const endDateStr = endDate.toISOString().split('T')[0];
    let totalGenerated = 0;
    for (const turf of activeTurfs) {
        const count = await generateSlotsForTurf(turf.id, startDateStr, endDateStr);
        totalGenerated += count;
    }
    return {
        turfsProcessed: activeTurfs.length,
        slotsGenerated: totalGenerated,
        startDateStr,
        endDateStr,
    };
}
async function blockSlots(courtId, date, startTime, endTime, reason) {
    // Update matching slots within the time window for the specified court
    const updatedSlots = await prisma_1.prisma.slot.updateMany({
        where: {
            courtId,
            date,
            startTime: { gte: startTime },
            endTime: { lte: endTime },
            status: { not: client_1.SlotStatus.BOOKED },
        },
        data: {
            status: client_1.SlotStatus.BLOCKED,
        },
    });
    // Create a blocked slot schedule record
    await prisma_1.prisma.blockedSlot.create({
        data: {
            courtId,
            date,
            startTime,
            endTime,
            reason,
        },
    });
    return updatedSlots.count;
}
