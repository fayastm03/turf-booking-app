"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.adminRoutes = adminRoutes;
const auth_1 = require("../../middleware/auth");
const prisma_1 = require("../../db/prisma");
const client_1 = require("@prisma/client");
const zod_1 = require("zod");
async function adminRoutes(fastify, options) {
    // Enforce ADMIN role on all /admin routes
    fastify.addHook('preHandler', auth_1.authenticate);
    fastify.addHook('preHandler', (0, auth_1.requireRoles)([client_1.SystemRole.ADMIN]));
    // GET /admin/owner-applications - List applications
    fastify.get('/owner-applications', async (request, reply) => {
        const apps = await prisma_1.prisma.ownerApplication.findMany({
            include: {
                user: {
                    select: {
                        id: true,
                        email: true,
                        name: true,
                        phone: true,
                    },
                },
            },
            orderBy: { createdAt: 'desc' },
        });
        return reply.status(200).send(apps);
    });
    // POST /admin/owner-applications/:id/approve - Approve an application
    fastify.post('/owner-applications/:id/approve', async (request, reply) => {
        const { id } = request.params;
        try {
            const application = await prisma_1.prisma.ownerApplication.findUnique({
                where: { id },
            });
            if (!application) {
                return reply.status(404).send({ error: 'Not Found', message: 'Application not found' });
            }
            if (application.status !== client_1.ApplicationStatus.PENDING) {
                return reply.status(400).send({ error: 'Bad Request', message: `Application already ${application.status.toLowerCase()}` });
            }
            // Update application status and add OWNER role to the user inside transaction
            await prisma_1.prisma.$transaction([
                prisma_1.prisma.ownerApplication.update({
                    where: { id },
                    data: { status: client_1.ApplicationStatus.APPROVED },
                }),
                prisma_1.prisma.user.update({
                    where: { id: application.userId },
                    data: {
                        roles: {
                            set: [client_1.SystemRole.USER, client_1.SystemRole.OWNER], // Give user both roles
                        },
                    },
                }),
            ]);
            return reply.status(200).send({ message: 'Application approved successfully, user is now an owner' });
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // POST /admin/owner-applications/:id/reject - Reject an application
    fastify.post('/owner-applications/:id/reject', async (request, reply) => {
        const { id } = request.params;
        try {
            const application = await prisma_1.prisma.ownerApplication.findUnique({
                where: { id },
            });
            if (!application) {
                return reply.status(404).send({ error: 'Not Found', message: 'Application not found' });
            }
            if (application.status !== client_1.ApplicationStatus.PENDING) {
                return reply.status(400).send({ error: 'Bad Request', message: `Application already ${application.status.toLowerCase()}` });
            }
            await prisma_1.prisma.ownerApplication.update({
                where: { id },
                data: { status: client_1.ApplicationStatus.REJECTED },
            });
            return reply.status(200).send({ message: 'Application rejected' });
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // POST /admin/offers - Create platform offer
    fastify.post('/offers', async (request, reply) => {
        const createOfferSchema = zod_1.z.object({
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
        try {
            const existingOffer = await prisma_1.prisma.offer.findUnique({
                where: { code: parsed.data.code },
            });
            if (existingOffer) {
                return reply.status(400).send({ error: 'Bad Request', message: 'Offer code already exists' });
            }
            const offer = await prisma_1.prisma.offer.create({
                data: {
                    scope: 'PLATFORM',
                    title: parsed.data.title,
                    code: parsed.data.code,
                    discountType: parsed.data.discountType,
                    value: parsed.data.value,
                    validFrom: new Date(parsed.data.validFrom),
                    validTo: new Date(parsed.data.validTo),
                    minBookingAmount: parsed.data.minBookingAmount || null,
                    isActive: true,
                },
            });
            return reply.status(201).send(offer);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
}
