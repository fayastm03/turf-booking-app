"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.offerRoutes = offerRoutes;
const auth_1 = require("../../middleware/auth");
const prisma_1 = require("../../db/prisma");
const client_1 = require("@prisma/client");
const zod_1 = require("zod");
async function offerRoutes(fastify, options) {
    // GET /offers/active - Browse active offers (Public)
    fastify.get('/active', async (request, reply) => {
        const querySchema = zod_1.z.object({
            turfId: zod_1.z.string().uuid().optional(),
        });
        const parsed = querySchema.safeParse(request.query);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        const { turfId } = parsed.data;
        const now = new Date();
        const where = {
            isActive: true,
            validFrom: { lte: now },
            validTo: { gte: now },
        };
        if (turfId) {
            where.OR = [
                { scope: client_1.OfferScope.PLATFORM },
                { scope: client_1.OfferScope.TURF, turfs: { some: { id: turfId } } },
            ];
        }
        else {
            where.scope = client_1.OfferScope.PLATFORM;
        }
        const offers = await prisma_1.prisma.offer.findMany({
            where,
            orderBy: { createdAt: 'desc' },
        });
        return reply.status(200).send(offers);
    });
    // POST /owner/offers - Create turf-specific offer (Owner only)
    fastify.post('/owner/offers', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const createOfferSchema = zod_1.z.object({
            turfId: zod_1.z.string().uuid(),
            title: zod_1.z.string().min(3),
            code: zod_1.z.string().toUpperCase().min(3),
            discountType: zod_1.z.enum(['PERCENT', 'FIXED']),
            value: zod_1.z.number().positive(),
            validFrom: zod_1.z.string().datetime(),
            validTo: zod_1.z.string().datetime(),
            minBookingAmount: zod_1.z.number().nonnegative().optional(),
        });
        const parsed = createOfferSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        // Verify turf ownership
        const turf = await prisma_1.prisma.turf.findUnique({
            where: { id: parsed.data.turfId },
        });
        if (!turf) {
            return reply.status(404).send({ error: 'Not Found', message: 'Turf not found' });
        }
        if (turf.ownerId !== request.user.id) {
            return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this turf' });
        }
        try {
            const existingOffer = await prisma_1.prisma.offer.findUnique({
                where: { code: parsed.data.code },
            });
            if (existingOffer) {
                return reply.status(400).send({ error: 'Bad Request', message: 'Offer code already exists' });
            }
            const offer = await prisma_1.prisma.offer.create({
                data: {
                    scope: client_1.OfferScope.TURF,
                    title: parsed.data.title,
                    code: parsed.data.code,
                    discountType: parsed.data.discountType,
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
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // GET /owner/offers - Get all offers for owned turfs (Owner only)
    fastify.get('/owner/offers', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const offers = await prisma_1.prisma.offer.findMany({
            where: {
                turfs: {
                    some: {
                        ownerId: request.user.id,
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
