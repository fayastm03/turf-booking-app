import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { authenticate, requireRoles } from '../../middleware/auth';
import { prisma } from '../../db/prisma';
import * as bookingService from './booking.service';
import { SystemRole } from '@prisma/client';
import { z } from 'zod';

export async function bookingRoutes(fastify: FastifyInstance, options: FastifyPluginOptions) {
  
  // Enforce authentication on all booking routes
  fastify.addHook('preHandler', authenticate);

  // POST /bookings/hold - Request a 5-minute hold on a slot
  fastify.post('/bookings/hold', async (request, reply) => {
    const holdSchema = z.object({
      slotId: z.string().uuid(),
      offerCode: z.string().optional(),
    });

    const parsed = holdSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    try {
      const result = await bookingService.holdSlot(
        request.user!.id,
        parsed.data.slotId,
        parsed.data.offerCode
      );
      return reply.status(201).send(result);
    } catch (err: any) {
      if (err.message.includes('not found')) {
        return reply.status(404).send({ error: 'Not Found', message: err.message });
      }
      return reply.status(409).send({ error: 'Conflict', message: err.message });
    }
  });

  // POST /bookings/:id/create-order - Create official Razorpay Order for held slot
  fastify.post('/bookings/:id/create-order', async (request, reply) => {
    const { id: bookingId } = request.params as { id: string };

    try {
      const orderDetails = await bookingService.createRazorpayOrder(request.user!.id, bookingId);
      return reply.status(200).send(orderDetails);
    } catch (err: any) {
      return reply.status(400).send({ error: 'Bad Request', message: err.message });
    }
  });

  // POST /bookings/verify-payment - Verify the Razorpay client signature before confirming.
  fastify.post('/bookings/verify-payment', async (request, reply) => {
    const schema = z.object({
      razorpayOrderId: z.string().min(1),
      razorpayPaymentId: z.string().min(1),
      razorpaySignature: z.string().min(1),
    });
    const parsed = schema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    try {
      const booking = await bookingService.verifyAndConfirmPayment(
        request.user!.id,
        parsed.data.razorpayOrderId,
        parsed.data.razorpayPaymentId,
        parsed.data.razorpaySignature,
      );
      return reply.status(200).send(booking);
    } catch (err: any) {
      return reply.status(400).send({ error: 'Bad Request', message: err.message });
    }
  });

  // POST /bookings/:id/cancel - User cancellations
  fastify.post('/bookings/:id/cancel', async (request, reply) => {
    const { id: bookingId } = request.params as { id: string };

    try {
      const cancelledBooking = await bookingService.cancelBooking(request.user!.id, bookingId);
      return reply.status(200).send(cancelledBooking);
    } catch (err: any) {
      return reply.status(400).send({ error: 'Bad Request', message: err.message });
    }
  });

  // GET /bookings/my - Fetch authenticated user's booking history
  fastify.get('/bookings/my', async (request, reply) => {
    const bookings = await prisma.booking.findMany({
      where: { userId: request.user!.id },
      include: {
        slot: {
          select: {
            date: true,
            startTime: true,
            endTime: true,
            court: {
              select: {
                name: true,
                type: true,
                turf: {
                  select: {
                    name: true,
                    address: true,
                    images: {
                      select: {
                        url: true,
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return reply.status(200).send(bookings);
  });

  // GET /owner/bookings - List all bookings made on owner's turfs (Owner role only)
  fastify.get('/owner/bookings', { preHandler: [requireRoles([SystemRole.OWNER])] }, async (request, reply) => {
    const bookings = await prisma.booking.findMany({
      where: {
        slot: {
          court: {
            turf: {
              ownerId: request.user!.id,
            },
          },
        },
      },
      include: {
        user: {
          select: {
            name: true,
            email: true,
            phone: true,
          },
        },
        slot: {
          select: {
            date: true,
            startTime: true,
            endTime: true,
            court: {
              select: {
                name: true,
                type: true,
                turf: {
                  select: {
                    name: true,
                  },
                },
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return reply.status(200).send(bookings);
  });
}
