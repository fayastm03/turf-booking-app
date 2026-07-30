"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.turfRoutes = turfRoutes;
const auth_1 = require("../../middleware/auth");
const prisma_1 = require("../../db/prisma");
const client_1 = require("@prisma/client");
const zod_1 = require("zod");
async function turfRoutes(fastify, options) {
    // ==========================================
    // PUBLIC ENDPOINTS
    // ==========================================
    // GET /cities - List active cities
    fastify.get('/cities', async (request, reply) => {
        try {
            const cities = await prisma_1.prisma.city.findMany({
                where: { isActive: true },
                orderBy: { name: 'asc' },
            });
            return reply.status(200).send(cities);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // GET /sports - List active sports
    fastify.get('/sports', async (request, reply) => {
        try {
            const sports = await prisma_1.prisma.sport.findMany({
                where: { isActive: true },
                orderBy: { name: 'asc' },
            });
            return reply.status(200).send(sports);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // GET /turfs - Browse active turfs
    fastify.get('/turfs', async (request, reply) => {
        const querySchema = zod_1.z.object({
            cityId: zod_1.z.string().uuid().optional(),
            search: zod_1.z.string().optional(),
            sportId: zod_1.z.string().uuid().optional(),
        });
        const parsed = querySchema.safeParse(request.query);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        const { cityId, search, sportId } = parsed.data;
        const where = {
            status: client_1.TurfStatus.ACTIVE,
        };
        if (cityId) {
            where.cityId = cityId;
        }
        if (sportId) {
            where.courts = {
                some: {
                    sports: {
                        some: {
                            id: sportId,
                        },
                    },
                },
            };
        }
        if (search) {
            where.OR = [
                { name: { contains: search, mode: 'insensitive' } },
                { description: { contains: search, mode: 'insensitive' } },
            ];
        }
        const turfs = await prisma_1.prisma.turf.findMany({
            where,
            include: {
                city: true,
                images: true,
                amenities: true,
                courts: {
                    include: {
                        sports: true,
                    },
                },
            },
            orderBy: { name: 'asc' },
        });
        return reply.status(200).send(turfs);
    });
    // GET /turfs/:id - Get detailed turf info
    fastify.get('/turfs/:id', async (request, reply) => {
        const { id } = request.params;
        const turf = await prisma_1.prisma.turf.findUnique({
            where: { id },
            include: {
                city: true,
                images: true,
                amenities: true,
                courts: {
                    include: {
                        sports: true,
                    },
                },
                owner: {
                    select: {
                        name: true,
                        email: true,
                    },
                },
            },
        });
        if (!turf || turf.status !== client_1.TurfStatus.ACTIVE) {
            return reply.status(404).send({ error: 'Not Found', message: 'Turf not found or inactive' });
        }
        return reply.status(200).send(turf);
    });
    // ==========================================
    // OWNER ENDPOINTS (PROTECTED)
    // ==========================================
    // GET /owner/turfs - List owned turfs
    fastify.get('/owner/turfs', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const turfs = await prisma_1.prisma.turf.findMany({
            where: { ownerId: request.user.id },
            include: {
                city: true,
                images: true,
                amenities: true,
                courts: true,
            },
            orderBy: { createdAt: 'desc' },
        });
        return reply.status(200).send(turfs);
    });
    // POST /owner/turfs - Register a new turf
    fastify.post('/owner/turfs', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const createTurfSchema = zod_1.z.object({
            name: zod_1.z.string().min(3),
            description: zod_1.z.string().min(10),
            address: zod_1.z.string().min(5),
            cityId: zod_1.z.string().uuid(),
            lat: zod_1.z.number().optional(),
            lng: zod_1.z.number().optional(),
            images: zod_1.z.array(zod_1.z.string().url()).default([]),
            amenities: zod_1.z.array(zod_1.z.string().uuid()).default([]),
            basePricePerHour: zod_1.z.number().positive(),
            openingTime: zod_1.z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'Must be in HH:MM format'),
            closingTime: zod_1.z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'Must be in HH:MM format'),
            slotDurationMinutes: zod_1.z.number().default(60),
        });
        const parsed = createTurfSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        const { images, amenities, ...rest } = parsed.data;
        try {
            const turf = await prisma_1.prisma.turf.create({
                data: {
                    ...rest,
                    ownerId: request.user.id,
                    status: client_1.TurfStatus.PENDING, // PENDING approval by admin
                    images: {
                        create: images.map((url) => ({ url })),
                    },
                    amenities: {
                        connect: amenities.map((id) => ({ id })),
                    },
                },
            });
            return reply.status(201).send(turf);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // PATCH /owner/turfs/:id - Update turf details
    fastify.patch('/owner/turfs/:id', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const { id } = request.params;
        // Check ownership
        const existingTurf = await prisma_1.prisma.turf.findUnique({ where: { id } });
        if (!existingTurf) {
            return reply.status(404).send({ error: 'Not Found', message: 'Turf not found' });
        }
        if (existingTurf.ownerId !== request.user.id) {
            return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this turf' });
        }
        const updateTurfSchema = zod_1.z.object({
            name: zod_1.z.string().min(3).optional(),
            description: zod_1.z.string().min(10).optional(),
            address: zod_1.z.string().min(5).optional(),
            cityId: zod_1.z.string().uuid().optional(),
            lat: zod_1.z.number().optional(),
            lng: zod_1.z.number().optional(),
            images: zod_1.z.array(zod_1.z.string().url()).optional(),
            amenities: zod_1.z.array(zod_1.z.string().uuid()).optional(),
            basePricePerHour: zod_1.z.number().positive().optional(),
            openingTime: zod_1.z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'Must be in HH:MM format').optional(),
            closingTime: zod_1.z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'Must be in HH:MM format').optional(),
            slotDurationMinutes: zod_1.z.number().optional(),
        });
        const parsed = updateTurfSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        const { images, amenities, ...rest } = parsed.data;
        try {
            const updated = await prisma_1.prisma.$transaction(async (tx) => {
                // Clear images if updated
                if (images) {
                    await tx.image.deleteMany({ where: { turfId: id } });
                }
                return tx.turf.update({
                    where: { id },
                    data: {
                        ...rest,
                        ...(images && {
                            images: {
                                create: images.map((url) => ({ url })),
                            },
                        }),
                        ...(amenities && {
                            amenities: {
                                set: amenities.map((aid) => ({ id: aid })),
                            },
                        }),
                    },
                });
            });
            return reply.status(200).send(updated);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // POST /owner/turfs/:id/courts - Add a court to a turf (Protected)
    fastify.post('/owner/turfs/:id/courts', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const { id: turfId } = request.params;
        const createCourtSchema = zod_1.z.object({
            name: zod_1.z.string().min(2),
            type: zod_1.z.string().min(2),
            pricePerHour: zod_1.z.number().positive(),
            sports: zod_1.z.array(zod_1.z.string().uuid()).min(1),
        });
        const parsed = createCourtSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        const { name, type, sports, pricePerHour } = parsed.data;
        const turf = await prisma_1.prisma.turf.findUnique({ where: { id: turfId } });
        if (!turf) {
            return reply.status(404).send({ error: 'Not Found', message: 'Turf not found' });
        }
        if (turf.ownerId !== request.user.id) {
            return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this turf' });
        }
        try {
            const court = await prisma_1.prisma.court.create({
                data: {
                    turfId,
                    name,
                    type,
                    pricePerHour,
                    sports: {
                        connect: sports.map((sid) => ({ id: sid })),
                    },
                },
                include: {
                    sports: true,
                },
            });
            return reply.status(201).send(court);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // GET /owner/analytics - Fetch revenue, utilization, and activity stats (Owner only)
    fastify.get('/owner/analytics', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const ownerId = request.user.id;
        try {
            // 1. Get all turfs owned by this user
            const turfs = await prisma_1.prisma.turf.findMany({
                where: { ownerId },
                select: { id: true },
            });
            const turfIds = turfs.map((t) => t.id);
            // 2. Fetch all confirmed bookings for these turfs
            const bookings = await prisma_1.prisma.booking.findMany({
                where: {
                    status: 'CONFIRMED',
                    slot: {
                        court: {
                            turfId: { in: turfIds },
                        },
                    },
                },
                include: {
                    user: {
                        select: { name: true },
                    },
                    slot: {
                        include: {
                            court: {
                                select: { name: true, turf: { select: { name: true } } },
                            },
                        },
                    },
                },
                orderBy: { createdAt: 'desc' },
            });
            // 3. Fetch slot statistics to calculate occupancy/utilization
            const totalSlots = await prisma_1.prisma.slot.count({
                where: {
                    court: {
                        turfId: { in: turfIds },
                    },
                },
            });
            const bookedSlots = await prisma_1.prisma.slot.count({
                where: {
                    status: 'BOOKED',
                    court: {
                        turfId: { in: turfIds },
                    },
                },
            });
            // 4. Aggregate calculations
            const totalRevenue = bookings.reduce((sum, b) => sum + b.amount, 0);
            const totalBookings = bookings.length;
            const utilizationRate = totalSlots > 0 ? bookedSlots / totalSlots : 0.0;
            // Weekly/Monthly aggregation for graph representation
            const monthlyRevenues = {};
            const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            for (const booking of bookings) {
                const date = new Date(booking.createdAt);
                const monthLabel = months[date.getMonth()];
                monthlyRevenues[monthLabel] = (monthlyRevenues[monthLabel] || 0) + booking.amount;
            }
            const monthlyStats = Object.keys(monthlyRevenues).map((month) => ({
                month,
                revenue: monthlyRevenues[month],
            }));
            // Return analytics summary package
            return reply.status(200).send({
                totalRevenue,
                totalBookings,
                utilizationRate,
                monthlyStats: monthlyStats.slice(0, 6), // past 6 records
                recentBookings: bookings.slice(0, 5).map((b) => ({
                    id: b.id,
                    userName: b.user.name,
                    turfName: b.slot.court.turf.name,
                    courtName: b.slot.court.name,
                    date: b.slot.date,
                    time: `${b.slot.startTime} - ${b.slot.endTime}`,
                    amount: b.amount,
                })),
            });
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
}
