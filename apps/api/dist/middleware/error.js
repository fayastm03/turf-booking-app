"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ForbiddenError = exports.UnauthorizedError = exports.ValidationError = exports.ConflictError = exports.NotFoundError = exports.AppError = void 0;
exports.globalErrorHandler = globalErrorHandler;
const zod_1 = require("zod");
class AppError extends Error {
    statusCode;
    error;
    details;
    constructor(statusCode, error, message, details) {
        super(message);
        this.statusCode = statusCode;
        this.error = error;
        this.details = details;
        Object.setPrototypeOf(this, new.target.prototype);
    }
}
exports.AppError = AppError;
class NotFoundError extends AppError {
    constructor(message = 'Resource not found') {
        super(404, 'NotFound', message);
    }
}
exports.NotFoundError = NotFoundError;
class ConflictError extends AppError {
    constructor(message = 'Conflict occurred') {
        super(409, 'Conflict', message);
    }
}
exports.ConflictError = ConflictError;
class ValidationError extends AppError {
    constructor(message = 'Validation failed', details) {
        super(400, 'ValidationError', message, details);
    }
}
exports.ValidationError = ValidationError;
class UnauthorizedError extends AppError {
    constructor(message = 'Unauthorized') {
        super(401, 'Unauthorized', message);
    }
}
exports.UnauthorizedError = UnauthorizedError;
class ForbiddenError extends AppError {
    constructor(message = 'Forbidden') {
        super(403, 'Forbidden', message);
    }
}
exports.ForbiddenError = ForbiddenError;
function globalErrorHandler(error, request, reply) {
    request.log.error(error);
    if (error instanceof AppError) {
        return reply.status(error.statusCode).send({
            error: error.error,
            message: error.message,
            details: error.details,
        });
    }
    if (error instanceof zod_1.ZodError) {
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
