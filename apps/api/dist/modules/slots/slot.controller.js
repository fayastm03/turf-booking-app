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
exports.slotRoutes = slotRoutes;
const auth_1 = require("../../middleware/auth");
const prisma_1 = require("../../db/prisma");
const slotService = __importStar(require("./slot.service"));
const client_1 = require("@prisma/client");
const zod_1 = require("zod");
async function slotRoutes(fastify, options) {
    // GET /turfs/:id/slots - Fetch slots for all courts of a turf on a date
    fastify.get('/turfs/:id/slots', async (request, reply) => {
        const { id: turfId } = request.params;
        const querySchema = zod_1.z.object({
            date: zod_1.z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be in YYYY-MM-DD format'),
        });
        const parsed = querySchema.safeParse(request.query);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        const { date } = parsed.data;
        const slots = await prisma_1.prisma.slot.findMany({
            where: {
                court: {
                    turfId,
                },
                date,
            },
            orderBy: { startTime: 'asc' },
        });
        return reply.status(200).send(slots);
    });
    // POST /owner/turfs/:id/block-slots - Block slots on a specific court (Owner only)
    fastify.post('/owner/turfs/:id/block-slots', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const { id: turfId } = request.params;
        // Ownership check
        const turf = await prisma_1.prisma.turf.findUnique({ where: { id: turfId } });
        if (!turf) {
            return reply.status(404).send({ error: 'Not Found', message: 'Turf not found' });
        }
        if (turf.ownerId !== request.user.id) {
            return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this turf' });
        }
        const blockSchema = zod_1.z.object({
            courtId: zod_1.z.string().uuid(),
            date: zod_1.z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD'),
            startTime: zod_1.z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'HH:MM format'),
            endTime: zod_1.z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'HH:MM format'),
            reason: zod_1.z.string().optional(),
        });
        const parsed = blockSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        const { courtId, date, startTime, endTime, reason } = parsed.data;
        // Verify court belongs to this turf
        const court = await prisma_1.prisma.court.findFirst({
            where: { id: courtId, turfId },
        });
        if (!court) {
            return reply.status(400).send({ error: 'Bad Request', message: 'Court does not belong to this turf' });
        }
        try {
            const count = await slotService.blockSlots(courtId, date, startTime, endTime, reason);
            return reply.status(200).send({ message: `Successfully blocked ${count} slots`, count });
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // POST /owner/turfs/:id/generate-slots - Manually generate slots for date range for all courts (Owner only)
    fastify.post('/owner/turfs/:id/generate-slots', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const { id: turfId } = request.params;
        const turf = await prisma_1.prisma.turf.findUnique({ where: { id: turfId } });
        if (!turf) {
            return reply.status(404).send({ error: 'Not Found', message: 'Turf not found' });
        }
        if (turf.ownerId !== request.user.id) {
            return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this turf' });
        }
        const generateSchema = zod_1.z.object({
            startDate: zod_1.z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD'),
            endDate: zod_1.z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD'),
        });
        const parsed = generateSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        try {
            const count = await slotService.generateSlotsForTurf(turfId, parsed.data.startDate, parsed.data.endDate);
            return reply.status(201).send({ message: `Generated ${count} slots for all courts`, count });
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // POST /admin/generate-slots - Trigger slot generation for all active turfs (Admin only)
    fastify.post('/admin/generate-slots', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.ADMIN])] }, async (request, reply) => {
        const adminSchema = zod_1.z.object({
            days: zod_1.z.number().min(1).max(90).default(30),
        });
        const parsed = adminSchema.safeParse(request.body);
        const days = parsed.success ? parsed.data.days : 30;
        try {
            const stats = await slotService.generateSlotsForAllActiveTurfs(days);
            return reply.status(201).send(stats);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // GET /owner/courts/:id/templates - List templates for a court (Owner only)
    fastify.get('/owner/courts/:id/templates', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const { id: courtId } = request.params;
        const court = await prisma_1.prisma.court.findUnique({
            where: { id: courtId },
            include: { turf: true },
        });
        if (!court) {
            return reply.status(404).send({ error: 'Not Found', message: 'Court not found' });
        }
        if (court.turf.ownerId !== request.user.id) {
            return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this court' });
        }
        try {
            const templates = await prisma_1.prisma.slotTemplate.findMany({
                where: { courtId },
                orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
            });
            return reply.status(200).send(templates);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // POST /owner/courts/:id/templates - Create a slot template for a court (Owner only)
    fastify.post('/owner/courts/:id/templates', { preHandler: [auth_1.authenticate, (0, auth_1.requireRoles)([client_1.SystemRole.OWNER])] }, async (request, reply) => {
        const { id: courtId } = request.params;
        const court = await prisma_1.prisma.court.findUnique({
            where: { id: courtId },
            include: { turf: true },
        });
        if (!court) {
            return reply.status(404).send({ error: 'Not Found', message: 'Court not found' });
        }
        if (court.turf.ownerId !== request.user.id) {
            return reply.status(403).send({ error: 'Forbidden', message: 'You do not own this court' });
        }
        const templateSchema = zod_1.z.object({
            dayOfWeek: zod_1.z.number().min(0).max(6),
            startTime: zod_1.z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'Must be in HH:MM format'),
            endTime: zod_1.z.string().regex(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/, 'Must be in HH:MM format'),
            priceOverride: zod_1.z.number().positive().optional(),
        });
        const parsed = templateSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        const { dayOfWeek, startTime, endTime, priceOverride } = parsed.data;
        try {
            const template = await prisma_1.prisma.slotTemplate.create({
                data: {
                    courtId,
                    dayOfWeek,
                    startTime,
                    endTime,
                    priceOverride: priceOverride ?? null,
                },
            });
            return reply.status(201).send(template);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
}
