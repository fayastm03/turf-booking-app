import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { authenticate, requireRoles } from '../../middleware/auth';
import { prisma } from '../../db/prisma';
import { SystemRole, ApplicationStatus } from '@prisma/client';
import { z } from 'zod';

export async function adminRoutes(fastify: FastifyInstance, options: FastifyPluginOptions) {
  // Enforce ADMIN role on all /admin routes
  fastify.addHook('preHandler', authenticate);
  fastify.addHook('preHandler', requireRoles([SystemRole.ADMIN]));

  // GET /admin/owner-applications - List applications
  fastify.get('/owner-applications', async (request, reply) => {
    const apps = await prisma.ownerApplication.findMany({
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
    const { id } = request.params as { id: string };

    try {
      const application = await prisma.ownerApplication.findUnique({
        where: { id },
      });

      if (!application) {
        return reply.status(404).send({ error: 'Not Found', message: 'Application not found' });
      }

      if (application.status !== ApplicationStatus.PENDING) {
        return reply.status(400).send({ error: 'Bad Request', message: `Application already ${application.status.toLowerCase()}` });
      }

      // Update application status and add OWNER role to the user inside transaction
      await prisma.$transaction([
        prisma.ownerApplication.update({
          where: { id },
          data: { status: ApplicationStatus.APPROVED },
        }),
        prisma.user.update({
          where: { id: application.userId },
          data: {
            roles: {
              set: [SystemRole.USER, SystemRole.OWNER], // Give user both roles
            },
          },
        }),
      ]);

      return reply.status(200).send({ message: 'Application approved successfully, user is now an owner' });
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });

  // POST /admin/owner-applications/:id/reject - Reject an application
  fastify.post('/owner-applications/:id/reject', async (request, reply) => {
    const { id } = request.params as { id: string };

    try {
      const application = await prisma.ownerApplication.findUnique({
        where: { id },
      });

      if (!application) {
        return reply.status(404).send({ error: 'Not Found', message: 'Application not found' });
      }

      if (application.status !== ApplicationStatus.PENDING) {
        return reply.status(400).send({ error: 'Bad Request', message: `Application already ${application.status.toLowerCase()}` });
      }

      await prisma.ownerApplication.update({
        where: { id },
        data: { status: ApplicationStatus.REJECTED },
      });

      return reply.status(200).send({ message: 'Application rejected' });
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });

  // POST /admin/offers - Create platform offer
  fastify.post('/offers', async (request, reply) => {
    const createOfferSchema = z.object({
      title: z.string().min(3),
      code: z.string().toUpperCase().min(3),
      discountType: z.enum(['PERCENT', 'FIXED']),
      value: z.number().positive(),
      validFrom: z.string().datetime(),
      validTo: z.string().datetime(),
      minBookingAmount: z.number().nonnegative().optional(),
    });

    const parsed = createOfferSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    try {
      const existingOffer = await prisma.offer.findUnique({
        where: { code: parsed.data.code },
      });
      if (existingOffer) {
        return reply.status(400).send({ error: 'Bad Request', message: 'Offer code already exists' });
      }

      const offer = await prisma.offer.create({
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
    } catch (err: any) {
      return reply.status(500).send({ error: 'Internal Server Error', message: err.message });
    }
  });
}
