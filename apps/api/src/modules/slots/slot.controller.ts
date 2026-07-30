import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { authenticate, requireRoles } from '../../middleware/auth';
import { prisma } from '../../db/prisma';
import * as slotService from './slot.service';
import { SystemRole } from '@prisma/client';
import { z } from 'zod';

export async function slotRoutes(fastify: FastifyInstance, options: FastifyPluginOptions) {
  
  // GET /turfs/:id/slots - Fetch slots for all courts of a turf on a date
  fastify.get('/turfs/:id/slots', async (request, reply) => {
    const { id: turfId } = request.params as { id: string };
    const querySchema = z.object({
      date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be in YYYY-MM-DD format'),
    });

    const parsed = querySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    const { date } = parsed.data;

    const slots = await prisma.slot.findMany({
      where: {
        court: {
          turfId,
        },
        date,
      },
      orderBy: { startTime: 'asc' },
    });

    return reply.status(200).send(slots);
  });

  // POST /owner/turfs/:id/block-slots - Block slots on a specific court (Owner only)
  fastify.post('/owner/turfs/:id/block-slots', { preHandler: [authenticate, requireRoles([SystemRole.OWNER])] }, async (request, reply) => {
    const { id: turfId } = request.params as { id: string };

    // Ownership check
    const turf = await prisma.turf.findUnique({ where: { id: turfId } });
    if (!turf) {
      return reply.status(404).send({ error: 'Not Found', message: 'Turf not found' });
    }
    if (turf.ownerId !== request.user!.id) {
      return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this turf' });
    }

    const blockSchema = z.object({
      courtId: z.string().uuid(),
      date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD'),
      startTime: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'HH:MM format'),
      endTime: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'HH:MM format'),
      reason: z.string().optional(),
    });

    const parsed = blockSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    const { courtId, date, startTime, endTime, reason } = parsed.data;

    // Verify court belongs to this turf
    const court = await prisma.court.findFirst({
      where: { id: courtId, turfId },
    });

    if (!court) {
      return reply.status(400).send({ error: 'Bad Request', message: 'Court does not belong to this turf' });
    }

    try {
      const count = await slotService.blockSlots(
        courtId,
        date,
        startTime,
        endTime,
        reason
      );
      return reply.status(200).send({ message: `Successfully blocked ${count} slots`, count });
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });

  // POST /owner/turfs/:id/generate-slots - Manually generate slots for date range for all courts (Owner only)
  fastify.post('/owner/turfs/:id/generate-slots', { preHandler: [authenticate, requireRoles([SystemRole.OWNER])] }, async (request, reply) => {
    const { id: turfId } = request.params as { id: string };

    const turf = await prisma.turf.findUnique({ where: { id: turfId } });
    if (!turf) {
      return reply.status(404).send({ error: 'Not Found', message: 'Turf not found' });
    }
    if (turf.ownerId !== request.user!.id) {
      return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this turf' });
    }

    const generateSchema = z.object({
      startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD'),
      endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD'),
    });

    const parsed = generateSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    try {
      const count = await slotService.generateSlotsForTurf(
        turfId,
        parsed.data.startDate,
        parsed.data.endDate
      );
      return reply.status(201).send({ message: `Generated ${count} slots for all courts`, count });
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });

  // POST /admin/generate-slots - Trigger slot generation for all active turfs (Admin only)
  fastify.post('/admin/generate-slots', { preHandler: [authenticate, requireRoles([SystemRole.ADMIN])] }, async (request, reply) => {
    const adminSchema = z.object({
      days: z.number().min(1).max(90).default(30),
    });

    const parsed = adminSchema.safeParse(request.body);
    const days = parsed.success ? parsed.data.days : 30;

    try {
      const stats = await slotService.generateSlotsForAllActiveTurfs(days);
      return reply.status(201).send(stats);
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });

  // GET /owner/courts/:id/templates - List templates for a court (Owner only)
  fastify.get('/owner/courts/:id/templates', { preHandler: [authenticate, requireRoles([SystemRole.OWNER])] }, async (request, reply) => {
    const { id: courtId } = request.params as { id: string };

    const court = await prisma.court.findUnique({
      where: { id: courtId },
      include: { turf: true },
    });

    if (!court) {
      return reply.status(404).send({ error: 'Not Found', message: 'Court not found' });
    }
    if (court.turf.ownerId !== request.user!.id) {
      return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this court' });
    }

    try {
      const templates = await prisma.slotTemplate.findMany({
        where: { courtId },
        orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
      });
      return reply.status(200).send(templates);
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });

  // POST /owner/courts/:id/templates - Create a slot template for a court (Owner only)
  fastify.post('/owner/courts/:id/templates', { preHandler: [authenticate, requireRoles([SystemRole.OWNER])] }, async (request, reply) => {
    const { id: courtId } = request.params as { id: string };

    const court = await prisma.court.findUnique({
      where: { id: courtId },
      include: { turf: true },
    });

    if (!court) {
      return reply.status(404).send({ error: 'Not Found', message: 'Court not found' });
    }
    if (court.turf.ownerId !== request.user!.id) {
      return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this court' });
    }

    const templateSchema = z.object({
      dayOfWeek: z.number().min(0).max(6),
      startTime: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'Must be in HH:MM format'),
      endTime: z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'Must be in HH:MM format'),
      priceOverride: z.number().positive().optional(),
    });

    const parsed = templateSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    const { dayOfWeek, startTime, endTime, priceOverride } = parsed.data;

    try {
      const template = await prisma.slotTemplate.create({
        data: {
          courtId,
          dayOfWeek,
          startTime,
          endTime,
          priceOverride: priceOverride ?? null,
        },
      });

      return reply.status(201).send(template);
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });
}
