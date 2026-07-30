import { prisma } from '../../db/prisma';
import { SlotStatus, Slot } from '@prisma/client';

export function getDatesInRange(startDateStr: string, endDateStr: string): string[] {
  const dates: string[] = [];
  const current = new Date(`${startDateStr}T00:00:00Z`);
  const end = new Date(`${endDateStr}T00:00:00Z`);

  while (current <= end) {
    dates.push(current.toISOString().split('T')[0]);
    current.setUTCDate(current.getUTCDate() + 1);
  }
  return dates;
}

export async function generateSlotsForTurf(turfId: string, startDateStr: string, endDateStr: string) {
  const courts = await prisma.court.findMany({
    where: { turfId, isActive: true },
    include: { slotTemplates: true },
  });

  const dates = getDatesInRange(startDateStr, endDateStr);
  const slotsToCreate: any[] = [];

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
          status: SlotStatus.AVAILABLE,
        });
      }
    }
  }

  if (slotsToCreate.length === 0) return 0;

  // Bulk create slots and skip duplicate conflicts
  const result = await prisma.slot.createMany({
    data: slotsToCreate,
    skipDuplicates: true,
  });

  return result.count;
}

export async function generateSlotsForAllActiveTurfs(daysCount = 30) {
  const activeTurfs = await prisma.turf.findMany({
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

export async function blockSlots(courtId: string, date: string, startTime: string, endTime: string, reason?: string) {
  // Update matching slots within the time window for the specified court
  const updatedSlots = await prisma.slot.updateMany({
    where: {
      courtId,
      date,
      startTime: { gte: startTime },
      endTime: { lte: endTime },
      status: { not: SlotStatus.BOOKED },
    },
    data: {
      status: SlotStatus.BLOCKED,
    },
  });

  // Create a blocked slot schedule record
  await prisma.blockedSlot.create({
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
