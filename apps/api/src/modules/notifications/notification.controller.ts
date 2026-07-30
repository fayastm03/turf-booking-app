import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { authenticate } from '../../middleware/auth';
import { prisma } from '../../db/prisma';
import { z } from 'zod';

export async function notificationRoutes(fastify: FastifyInstance, options: FastifyPluginOptions) {
  
  // Enforce authentication on all notifications routes
  fastify.addHook('preHandler', authenticate);

  // GET /notifications - Retrieve user's notifications
  fastify.get('/notifications', async (request, reply) => {
    try {
      const notifications = await prisma.notification.findMany({
        where: { userId: request.user!.id },
        orderBy: { createdAt: 'desc' },
      });
      return reply.status(200).send(notifications);
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });

  // PUT /notifications/:id/read - Mark notification as read
  fastify.put('/notifications/:id/read', async (request, reply) => {
    const { id } = request.params as { id: string };

    try {
      const notification = await prisma.notification.findUnique({
        where: { id },
      });

      if (!notification || notification.userId !== request.user!.id) {
        return reply.status(404).send({ error: 'Not Found', message: 'Notification not found' });
      }

      const updated = await prisma.notification.update({
        where: { id },
        data: { isRead: true },
      });

      return reply.status(200).send(updated);
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });

  // PUT /notifications/read-all - Mark all user's notifications as read
  fastify.put('/notifications/read-all', async (request, reply) => {
    try {
      await prisma.notification.updateMany({
        where: { userId: request.user!.id, isRead: false },
        data: { isRead: true },
      });

      const updatedList = await prisma.notification.findMany({
        where: { userId: request.user!.id },
        orderBy: { createdAt: 'desc' },
      });

      return reply.status(200).send(updatedList);
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });
}
