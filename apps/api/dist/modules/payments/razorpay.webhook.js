"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.webhookRoutes = webhookRoutes;
const crypto_1 = __importDefault(require("crypto"));
const config_1 = require("../../config");
const prisma_1 = require("../../db/prisma");
const bookingService = __importStar(require("../bookings/booking.service"));
async function webhookRoutes(fastify, options) {
    // POST /webhooks/razorpay - Razorpay webhook handler
    fastify.post('/razorpay', async (request, reply) => {
        const signature = request.headers['x-razorpay-signature'];
        if (!signature) {
            return reply.status(400).send({ error: 'Bad Request', message: 'Missing Razorpay signature' });
        }
        // Access raw body captured by content type parser
        const rawBody = request.rawBody;
        if (!rawBody) {
            return reply.status(400).send({ error: 'Bad Request', message: 'Missing raw body context' });
        }
        // Verify webhook signature
        const hmac = crypto_1.default.createHmac('sha256', config_1.config.RAZORPAY_WEBHOOK_SECRET);
        hmac.update(rawBody);
        const expectedSignature = hmac.digest('hex');
        if (expectedSignature !== signature) {
            return reply.status(400).send({ error: 'Unauthorized', message: 'Invalid webhook signature' });
        }
        const payload = request.body;
        const eventId = payload.id;
        // 1. Idempotency Check
        const existingEvent = await prisma_1.prisma.paymentEvent.findUnique({
            where: { razorpayEventId: eventId },
        });
        if (existingEvent) {
            // Event already processed, return 200 OK
            return reply.status(200).send({ status: 'ignored', message: 'Event already processed' });
        }
        // Store event for audit log and idempotency
        await prisma_1.prisma.paymentEvent.create({
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
                }
                catch (err) {
                    console.error(`❌ Error confirming booking for order ID ${orderId}:`, err);
                    // Return 500 so Razorpay retries
                    return reply.status(500).send({ error: 'Confirmation Failed', message: err.message });
                }
            }
        }
        return reply.status(200).send({ status: 'ok' });
    });
}
