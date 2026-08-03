import { FastifyInstance, FastifyPluginOptions } from 'fastify';
import { z } from 'zod';
import * as authService from './auth.service';
import { authenticate } from '../../middleware/auth';
import { prisma } from '../../db/prisma';

export async function authRoutes(fastify: FastifyInstance, options: FastifyPluginOptions) {
  
  // POST /auth/register
  fastify.post('/register', async (request, reply) => {
    const registerSchema = z.object({
      email: z.string().email(),
      password: z.string().min(6),
      name: z.string().min(2),
      phone: z.string().optional(),
      accountType: z.enum(['USER', 'OWNER']).default('USER'),
      businessName: z.string().min(3).optional(),
    }).superRefine((data, ctx) => {
      if (data.accountType === 'OWNER' && !data.businessName) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['businessName'], message: 'Business name is required for turf owners' });
      }
    });

    const parsed = registerSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    try {
      const tokens = await authService.register(
        parsed.data.email,
        parsed.data.password,
        parsed.data.name,
        parsed.data.phone,
        parsed.data.accountType,
        parsed.data.businessName,
      );
      return reply.status(201).send(tokens);
    } catch (err: any) {
      return reply.status(400).send({ error: 'Bad Request', message: err.message });
    }
  });

  // POST /auth/login
  fastify.post('/login', async (request, reply) => {
    const loginSchema = z.object({
      email: z.string().email(),
      password: z.string(),
      accountType: z.enum(['USER', 'OWNER']).default('USER'),
    });

    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    try {
      const result = await authService.login(parsed.data.email, parsed.data.password, parsed.data.accountType);
      return reply.status(200).send(result);
    } catch (err: any) {
      return reply.status(401).send({ error: 'Unauthorized', message: err.message });
    }
  });

  // POST /auth/refresh
  fastify.post('/refresh', async (request, reply) => {
    const refreshSchema = z.object({
      refreshToken: z.string(),
    });

    const parsed = refreshSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    try {
      const tokens = await authService.refresh(parsed.data.refreshToken);
      return reply.status(200).send(tokens);
    } catch (err: any) {
      return reply.status(401).send({ error: 'Unauthorized', message: err.message });
    }
  });

  // POST /auth/owner-apply (Protected)
  fastify.post('/owner-apply', { preHandler: [authenticate] }, async (request, reply) => {
    const ownerApplySchema = z.object({
      businessName: z.string().min(3),
      documents: z.any().optional(),
    });

    const parsed = ownerApplySchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
    }

    try {
      const app = await authService.applyForOwner(
        request.user!.id,
        parsed.data.businessName,
        parsed.data.documents
      );
      return reply.status(201).send(app);
    } catch (err: any) {
      return reply.status(400).send({ error: 'Bad Request', message: err.message });
    }
  });

  // GET /auth/me (Protected)
  fastify.get('/me', { preHandler: [authenticate] }, async (request, reply) => {
    const user = await prisma.user.findUnique({
      where: { id: request.user!.id },
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        roles: true,
        status: true,
        ownerApplication: true,
      },
    });

    if (!user) {
      return reply.status(404).send({ error: 'Not Found', message: 'User not found' });
    }

    return reply.status(200).send(user);
  });
}
