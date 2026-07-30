"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.reviewRoutes = reviewRoutes;
const auth_1 = require("../../middleware/auth");
const prisma_1 = require("../../db/prisma");
const zod_1 = require("zod");
async function reviewRoutes(fastify, options) {
    // GET /turfs/:id/reviews - Fetch all reviews for a turf (Public)
    fastify.get('/turfs/:id/reviews', async (request, reply) => {
        const { id: turfId } = request.params;
        try {
            const reviews = await prisma_1.prisma.review.findMany({
                where: { turfId },
                include: {
                    user: {
                        select: {
                            name: true,
                        },
                    },
                },
                orderBy: { createdAt: 'desc' },
            });
            return reply.status(200).send(reviews);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // POST /turfs/:id/reviews - Create a review for a turf (Protected)
    fastify.post('/turfs/:id/reviews', { preHandler: [auth_1.authenticate] }, async (request, reply) => {
        const { id: turfId } = request.params;
        const reviewSchema = zod_1.z.object({
            rating: zod_1.z.number().min(1).max(5),
            comment: zod_1.z.string().optional(),
        });
        const parsed = reviewSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        // 1. Verify Turf exists
        const turf = await prisma_1.prisma.turf.findUnique({ where: { id: turfId } });
        if (!turf) {
            return reply.status(404).send({ error: 'Not Found', message: 'Turf not found' });
        }
        // 2. Verify User has a past CONFIRMED booking for this turf
        const hasBooking = await prisma_1.prisma.booking.findFirst({
            where: {
                userId: request.user.id,
                status: 'CONFIRMED',
                slot: {
                    court: {
                        turfId,
                    },
                },
            },
        });
        if (!hasBooking) {
            return reply.status(403).send({
                error: 'Forbidden',
                message: 'You must have a confirmed booking at this turf to submit a review.',
            });
        }
        // 3. Create Review
        try {
            const review = await prisma_1.prisma.review.create({
                data: {
                    userId: request.user.id,
                    turfId,
                    rating: parsed.data.rating,
                    comment: parsed.data.comment || null,
                },
            });
            return reply.status(201).send(review);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
}
