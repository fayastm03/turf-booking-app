import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { authenticate, requireRoles } from '../../middleware/auth';
import { prisma } from '../../db/prisma';
import { SystemRole, OfferScope, DiscountType } from '@prisma/client';
import { z } from 'zod';

export async function offerRoutes(fastify: FastifyInstance, options: FastifyPluginOptions) {
  
  // GET /offers/active - Browse active offers (Public)
  fastify.get('/active', async (request, reply) => {
    const querySchema = z.object({
      turfId: z.string().uuid().optional(),
    });

    const parsed = querySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    const { turfId } = parsed.data;
    const now = new Date();

    const where: any = {
      isActive: true,
      validFrom: { lte: now },
      validTo: { gte: now },
    };

    if (turfId) {
      where.OR = [
        { scope: OfferScope.PLATFORM },
        { scope: OfferScope.TURF, turfs: { some: { id: turfId } } },
      ];
    } else {
      where.scope = OfferScope.PLATFORM;
    }

    const offers = await prisma.offer.findMany({
      where,
      orderBy: { createdAt: 'desc' },
    });

    return reply.status(200).send(offers);
  });

  // POST /owner/offers - Create turf-specific offer (Owner only)
  fastify.post('/owner/offers', { preHandler: [authenticate, requireRoles([SystemRole.OWNER])] }, async (request, reply) => {
    const createOfferSchema = z.object({
      turfId: z.string().uuid(),
      title: z.string().min(3),
      code: z.string().toUpperCase().min(3),
      discountType: z.enum(['PERCENT', 'FIXED']),
      value: z.number().positive(),
      validFrom: z.string().datetime(),
      validTo: z.string().datetime(),
      minBookingAmount: z.number().nonnegative().optional(),
    });

    const parsed = createOfferSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    // Verify turf ownership
    const turf = await prisma.turf.findUnique({
      where: { id: parsed.data.turfId },
    });

    if (!turf) {
      return reply.status(404).send({ error: 'Not Found', message: 'Turf not found' });
    }

    if (turf.ownerId !== request.user!.id) {
      return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this turf' });
    }

    try {
      const existingOffer = await prisma.offer.findUnique({
        where: { code: parsed.data.code },
      });
      if (existingOffer) {
        return reply.status(400).send({ error: 'Bad Request', message: 'Offer code already exists' });
      }

      const offer = await prisma.offer.create({
        data: {
          scope: OfferScope.TURF,
          title: parsed.data.title,
          code: parsed.data.code,
          discountType: parsed.data.discountType as DiscountType,
          value: parsed.data.value,
          validFrom: new Date(parsed.data.validFrom),
          validTo: new Date(parsed.data.validTo),
          minBookingAmount: parsed.data.minBookingAmount || null,
          isActive: true,
          turfs: {
            connect: { id: parsed.data.turfId },
          },
        },
      });

      return reply.status(201).send(offer);
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });

  // GET /owner/offers - Get all offers for owned turfs (Owner only)
  fastify.get('/owner/offers', { preHandler: [authenticate, requireRoles([SystemRole.OWNER])] }, async (request, reply) => {
    const offers = await prisma.offer.findMany({
      where: {
        turfs: {
          some: {
            ownerId: request.user!.id,
          },
        },
      },
      include: {
        turfs: {
          select: {
            name: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return reply.status(200).send(offers);
  });
}
