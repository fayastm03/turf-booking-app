import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import crypto from 'crypto';
import { config } from '../../config';
import { prisma } from '../../db/prisma';
import * as bookingService from '../bookings/booking.service';

export async function webhookRoutes(fastify: FastifyInstance, options: FastifyPluginOptions) {
  
  // POST /webhooks/razorpay - Razorpay webhook handler
  fastify.post('/razorpay', async (request, reply) => {
    const signature = request.headers['x-razorpay-signature'] as string;
    if (!signature) {
      return reply.status(400).send({ error: 'Bad Request', message: 'Missing Razorpay signature' });
    }

    // Access raw body captured by content type parser
    const rawBody = (request as any).rawBody;
    if (!rawBody) {
      return reply.status(400).send({ error: 'Bad Request', message: 'Missing raw body context' });
    }

    // Verify webhook signature
    const hmac = crypto.createHmac('sha256', config.RAZORPAY_WEBHOOK_SECRET);
    hmac.update(rawBody);
    const expectedSignature = hmac.digest('hex');

    if (expectedSignature !== signature) {
      return reply.status(400).send({ error: 'Unauthorized', message: 'Invalid webhook signature' });
    }

    const payload = request.body as any;
    const eventId = payload.id;

    // 1. Idempotency Check
    const existingEvent = await prisma.paymentEvent.findUnique({
      where: { razorpayEventId: eventId },
    });

    if (existingEvent) {
      // Event already processed, return 200 OK
      return reply.status(200).send({ status: 'ignored', message: 'Event already processed' });
    }

    // Store event for audit log and idempotency
    await prisma.paymentEvent.create({
      data: {
        razorpayEventId: eventId,
        payload: payload,
      },
    });

    // 2. Process payment capture event
    if (payload.event === 'payment.captured') {
      const paymentEntity = payload.payload.payment.entity;
      const orderId = paymentEntity.order_id;
      const paymentId = paymentEntity.id;

      if (orderId) {
        try {
          await bookingService.confirmBooking(orderId, paymentId);
          console.log(`✅ Booking confirmed successfully for order ID: ${orderId}`);
        } catch (err: any) {
          console.error(`❌ Error confirming booking for order ID ${orderId}:`, err);
          // Return 500 so Razorpay retries
          return reply.status(500).send({ error: 'Confirmation Failed', message: err.message });
        }
      }
    }

    return reply.status(200).send({ status: 'ok' });
  });
}
