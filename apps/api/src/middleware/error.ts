import { FastifyReply, FastifyRequest } from 'fastify';
import { ZodError } from 'zod';

export class AppError extends Error {
  constructor(
    public statusCode: number,
    public error: string,
    message: string,
    public details?: any
  ) {
    super(message);
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found') {
    super(404, 'NotFound', message);
  }
}

export class ConflictError extends AppError {
  constructor(message = 'Conflict occurred') {
    super(409, 'Conflict', message);
  }
}

export class ValidationError extends AppError {
  constructor(message = 'Validation failed', details?: any) {
    super(400, 'ValidationError', message, details);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super(401, 'Unauthorized', message);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Forbidden') {
    super(403, 'Forbidden', message);
  }
}

export function globalErrorHandler(error: any, request: FastifyRequest, reply: FastifyReply) {
  request.log.error(error);

  if (error instanceof AppError) {
    return reply.status(error.statusCode).send({
      error: error.error,
      message: error.message,
      details: error.details,
    });
  }

  if (error instanceof ZodError) {
    return reply.status(400).send({
      error: 'ValidationError',
      message: 'Input validation failed',
      details: error.flatten().fieldErrors,
    });
  }

  if (error.validation) {
    return reply.status(400).send({
      error: 'ValidationError',
      message: error.message,
      details: error.validation,
    });
  }

  return reply.status(500).send({
    error: 'InternalServerError',
    message: process.env.NODE_ENV === 'production' 
      ? 'An unexpected database or server error occurred' 
      : error.message,
  });
}
