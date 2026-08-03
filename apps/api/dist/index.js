"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const fastify_1 = __importDefault(require("fastify"));
const cors_1 = __importDefault(require("@fastify/cors"));
const rate_limit_1 = __importDefault(require("@fastify/rate-limit"));
const config_1 = require("./config");
const prisma_1 = require("./db/prisma");
const redis_1 = require("./db/redis");
const auth_controller_1 = require("./modules/auth/auth.controller");
const admin_controller_1 = require("./modules/admin/admin.controller");
const turf_controller_1 = require("./modules/turfs/turf.controller");
const slot_controller_1 = require("./modules/slots/slot.controller");
const review_controller_1 = require("./modules/reviews/review.controller");
const wallet_controller_1 = require("./modules/wallets/wallet.controller");
const booking_controller_1 = require("./modules/bookings/booking.controller");
const razorpay_webhook_1 = require("./modules/payments/razorpay.webhook");
const offer_controller_1 = require("./modules/offers/offer.controller");
const notification_controller_1 = require("./modules/notifications/notification.controller");
const error_1 = require("./middleware/error");
const booking_service_1 = require("./modules/bookings/booking.service");
const fastify = (0, fastify_1.default)({
    logger: {
        transport: process.env.NODE_ENV !== 'production'
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
    const bodyStr = typeof body === 'string' ? body : body.toString('utf8');
    request.rawBody = bodyStr;
    try {
        const json = bodyStr.trim() ? JSON.parse(bodyStr) : {};
        done(null, json);
    }
    catch (err) {
        done(err, null);
    }
});
async function main() {
    // CORS configuration
    await fastify.register(cors_1.default, {
        origin: true, // Allow all origins for dev client testing
        credentials: true,
    });
    // Redis-backed Rate Limiter
    await fastify.register(rate_limit_1.default, {
        redis: redis_1.redis,
        max: process.env.NODE_ENV === 'production' ? 100 : 10000, // Large threshold in dev
        timeWindow: '1 minute',
    });
    // Root Health Check Route
    fastify.get('/health', async (request, reply) => {
        return { status: 'OK', timestamp: new Date() };
    });
    // Register Module Routes
    await fastify.register(auth_controller_1.authRoutes, { prefix: '/auth' });
    await fastify.register(admin_controller_1.adminRoutes, { prefix: '/admin' });
    await fastify.register(turf_controller_1.turfRoutes);
    await fastify.register(slot_controller_1.slotRoutes);
    await fastify.register(booking_controller_1.bookingRoutes);
    await fastify.register(razorpay_webhook_1.webhookRoutes, { prefix: '/webhooks' });
    await fastify.register(offer_controller_1.offerRoutes, { prefix: '/offers' });
    await fastify.register(review_controller_1.reviewRoutes);
    await fastify.register(wallet_controller_1.walletRoutes);
    await fastify.register(notification_controller_1.notificationRoutes);
    // Centralized Global Error Handler
    fastify.setErrorHandler(error_1.globalErrorHandler);
    // Start Server
    try {
        await fastify.listen({ port: config_1.config.PORT, host: '0.0.0.0' });
        console.log(`🚀 Turf Booking API listening on port ${config_1.config.PORT}`);
        // Cron cleanup schedule (Check and release expired booking holds every 1 minute)
        setInterval(async () => {
            try {
                const count = await (0, booking_service_1.cleanupExpiredBookings)();
                if (count > 0) {
                    fastify.log.info(`🧹 Released ${count} expired booking holds`);
                }
            }
            catch (err) {
                console.error('Failed to run expired booking cleanup job:', err);
            }
        }, 60000);
    }
    catch (err) {
        fastify.log.error(err);
        process.exit(1);
    }
}
// Global cleanup handlers
const shutdown = async () => {
    await prisma_1.prisma.$disconnect();
    await redis_1.redis.quit();
    process.exit(0);
};
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
main();
