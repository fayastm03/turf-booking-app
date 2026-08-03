import Fastify from 'fastify';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import { config } from './config';
import { prisma } from './db/prisma';
import { redis } from './db/redis';
import { authRoutes } from './modules/auth/auth.controller';
import { adminRoutes } from './modules/admin/admin.controller';
import { turfRoutes } from './modules/turfs/turf.controller';
import { slotRoutes } from './modules/slots/slot.controller';
import { reviewRoutes } from './modules/reviews/review.controller';
import { walletRoutes } from './modules/wallets/wallet.controller';
import { bookingRoutes } from './modules/bookings/booking.controller';
import { webhookRoutes } from './modules/payments/razorpay.webhook';
import { offerRoutes } from './modules/offers/offer.controller';
import { notificationRoutes } from './modules/notifications/notification.controller';
import { globalErrorHandler } from './middleware/error';
import { cleanupExpiredBookings } from './modules/bookings/booking.service';

const fastify = Fastify({
  logger: {
    transport:
      process.env.NODE_ENV !== 'production'
        ? {
            target: 'pino-pretty',
            options: {
              translateTime: 'HH:MM:ss Z',
              ignore: 'pid,hostname',
            },
          }
        : undefined,
  },
});

fastify.addContentTypeParser('application/json', { parseAs: 'string' }, (request, body, done) => {
  const bodyStr = typeof body === 'string' ? body : (body as Buffer).toString('utf8');
  (request as any).rawBody = bodyStr;
  try {
    const json = bodyStr.trim() ? JSON.parse(bodyStr) : {};
    done(null, json);
  } catch (err: any) {
    done(err, null);
  }
});

async function main() {
  // CORS configuration
  await fastify.register(cors, {
    origin: true, // Allow all origins for dev client testing
    credentials: true,
  });

  // Redis-backed Rate Limiter
  await fastify.register(rateLimit, {
    redis: redis,
    max: process.env.NODE_ENV === 'production' ? 100 : 10000, // Large threshold in dev
    timeWindow: '1 minute',
  });

  // Root Health Check Route
  fastify.get('/health', async (request, reply) => {
    return { status: 'OK', timestamp: new Date() };
  });

  // Register Module Routes
  await fastify.register(authRoutes, { prefix: '/auth' });
  await fastify.register(adminRoutes, { prefix: '/admin' });
  await fastify.register(turfRoutes);
  await fastify.register(slotRoutes);
  await fastify.register(bookingRoutes);
  await fastify.register(webhookRoutes, { prefix: '/webhooks' });
  await fastify.register(offerRoutes, { prefix: '/offers' });
  await fastify.register(reviewRoutes);
  await fastify.register(walletRoutes);
  await fastify.register(notificationRoutes);

  // Centralized Global Error Handler
  fastify.setErrorHandler(globalErrorHandler);

  // Start Server
  try {
    await fastify.listen({ port: config.PORT, host: '0.0.0.0' });
    console.log(`🚀 Turf Booking API listening on port ${config.PORT}`);

    // Cron cleanup schedule (Check and release expired booking holds every 1 minute)
    setInterval(async () => {
      try {
        const count = await cleanupExpiredBookings();
        if (count > 0) {
          fastify.log.info(`🧹 Released ${count} expired booking holds`);
        }
      } catch (err) {
        console.error('Failed to run expired booking cleanup job:', err);
      }
    }, 60000);

  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
}

// Global cleanup handlers
const shutdown = async () => {
  await prisma.$disconnect();
  await redis.quit();
  process.exit(0);
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

main();
