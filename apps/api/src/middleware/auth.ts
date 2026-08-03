import { FastifyReply, FastifyRequest } from 'fastify';
import * as jose from 'jose';
import { config } from '../config';
import { SystemRole } from '@prisma/client';

declare module 'fastify' {
  interface FastifyRequest {
    user?: {
      id: string;
      email: string;
      roles: SystemRole[];
    };
  }
}

const JWT_SECRET_BYTES = new TextEncoder().encode(config.JWT_SECRET);

export async function authenticate(request: FastifyRequest, reply: FastifyReply) {
  try {
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return reply.status(401).send({ error: 'Unauthorized', message: 'Missing or invalid authorization header' });
    }

    const token = authHeader.split(' ')[1];
    const { payload } = await jose.jwtVerify(token, JWT_SECRET_BYTES);

    request.user = {
      id: payload.sub as string,
      email: payload.email as string,
      roles: payload.roles as SystemRole[],
    };
  } catch (err) {
    return reply.status(401).send({ error: 'Unauthorized', message: 'Invalid or expired token' });
  }
}

export function requireRoles(roles: SystemRole[]) {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) {
      return reply.status(401).send({ error: 'Unauthorized', message: 'User not authenticated' });
    }

    const hasRole = request.user.roles.some((r) => 
      roles.includes(r) || 
      (roles.includes(SystemRole.OWNER) && r === SystemRole.USER)
    );
    if (!hasRole) {
      return reply.status(403).send({ error: 'Forbidden', message: 'Insufficient permissions' });
    }
  };
}
