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
Object.defineProperty(exports, "__esModule", { value: true });
exports.bookingRoutes = bookingRoutes;
const auth_1 = require("../../middleware/auth");
const prisma_1 = require("../../db/prisma");
const bookingService = __importStar(require("./booking.service"));
const client_1 = require("@prisma/client");
const zod_1 = require("zod");
async function bookingRoutes(fastify, options) {
    // Enforce authentication on all booking routes
    fastify.addHook('preHandler', auth_1.authenticate);
    // POST /bookings/hold - Request a 5-minute hold on a slot
    fastify.post('/bookings/hold', async (request, reply) => {
        const holdSchema = zod_1.z.object({
            slotId: zod_1.z.string().uuid(),
            offerCode: zod_1.z.string().optional(),
        });
        const parsed = holdSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        try {
            const result = await bookingService.holdSlot(request.user.id, parsed.data.slotId, parsed.data.offerCode);
            return reply.status(201).send(result);
        }
        catch (err) {
            if (err.message.includes('not found')) {
                return reply.status(404).send({ error: 'Not Found', message: err.message });
            }
            return reply.status(409).send({ error: 'Conflict', message: err.message });
        }
    });
    // POST /bookings/:id/create-order - Create official Razorpay Order for held slot
    fastify.post('/bookings/:id/create-order', async (request, reply) => {
        const { id: bookingId } = request.params;
        try {
            const orderDetails = await bookingService.createRazorpayOrder(bookingId);
            return reply.status(200).send(orderDetails);
        }
        catch (err) {
            return reply.status(400).send({ error: 'Bad Request', message: err.message });
        }
    });
    // POST /bookings/:id/cancel - User cancellations
    fastify.post('/bookings/:id/cancel', async (request, reply) => {
        const { id: bookingId } = request.params;
        try {
            const cancelledBooking = await bookingService.cancelBooking(request.user.id, bookingId);
            return reply.status(200).send(cancelledBooking);
        }
        catch (err) {
            return reply.status(400).send({ error: 'Bad Request', message: err.message });
        }
    });
    // GET /bookings/my - Fetch authenticated user's booking history
    fastify.get('/bookings/my', async (request, reply) => {
        const bookings = await prisma_1.prisma.booking.findMany({
            where: { userId: request.user.id },
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
    fastify.get('/owner/bookings', { preHandler: [(0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const bookings = await prisma_1.prisma.booking.findMany({
            where: {
                slot: {
                    court: {
                        turf: {
                            ownerId: request.user.id,
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
