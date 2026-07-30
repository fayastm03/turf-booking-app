"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.notificationRoutes = notificationRoutes;
const auth_1 = require("../../middleware/auth");
const prisma_1 = require("../../db/prisma");
async function notificationRoutes(fastify, options) {
    // Enforce authentication on all notifications routes
    fastify.addHook('preHandler', auth_1.authenticate);
    // GET /notifications - Retrieve user's notifications
    fastify.get('/notifications', async (request, reply) => {
        try {
            const notifications = await prisma_1.prisma.notification.findMany({
                where: { userId: request.user.id },
                orderBy: { createdAt: 'desc' },
            });
            return reply.status(200).send(notifications);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // PUT /notifications/:id/read - Mark notification as read
    fastify.put('/notifications/:id/read', async (request, reply) => {
        const { id } = request.params;
        try {
            const notification = await prisma_1.prisma.notification.findUnique({
                where: { id },
            });
            if (!notification || notification.userId !== request.user.id) {
                return reply.status(404).send({ error: 'Not Found', message: 'Notification not found' });
            }
            const updated = await prisma_1.prisma.notification.update({
                where: { id },
                data: { isRead: true },
            });
            return reply.status(200).send(updated);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
    // PUT /notifications/read-all - Mark all user's notifications as read
    fastify.put('/notifications/read-all', async (request, reply) => {
        try {
            await prisma_1.prisma.notification.updateMany({
                where: { userId: request.user.id, isRead: false },
                data: { isRead: true },
            });
            const updatedList = await prisma_1.prisma.notification.findMany({
                where: { userId: request.user.id },
                orderBy: { createdAt: 'desc' },
            });
            return reply.status(200).send(updatedList);
        }
        catch (err) {
            return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
        }
    });
}
