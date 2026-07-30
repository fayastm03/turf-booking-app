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
exports.authRoutes = authRoutes;
const zod_1 = require("zod");
const authService = __importStar(require("./auth.service"));
const auth_1 = require("../../middleware/auth");
const prisma_1 = require("../../db/prisma");
async function authRoutes(fastify, options) {
    // POST /auth/register
    fastify.post('/register', async (request, reply) => {
        const registerSchema = zod_1.z.object({
            email: zod_1.z.string().email(),
            password: zod_1.z.string().min(6),
            name: zod_1.z.string().min(2),
            phone: zod_1.z.string().optional(),
        });
        const parsed = registerSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        try {
            const tokens = await authService.register(parsed.data.email, parsed.data.password, parsed.data.name, parsed.data.phone);
            return reply.status(201).send(tokens);
        }
        catch (err) {
            return reply.status(400).send({ error: 'Bad Request', message: err.message });
        }
    });
    // POST /auth/login
    fastify.post('/login', async (request, reply) => {
        const loginSchema = zod_1.z.object({
            email: zod_1.z.string().email(),
            password: zod_1.z.string(),
        });
        const parsed = loginSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        try {
            const result = await authService.login(parsed.data.email, parsed.data.password);
            return reply.status(200).send(result);
        }
        catch (err) {
            return reply.status(401).send({ error: 'Unauthorized', message: err.message });
        }
    });
    // POST /auth/refresh
    fastify.post('/refresh', async (request, reply) => {
        const refreshSchema = zod_1.z.object({
            refreshToken: zod_1.z.string(),
        });
        const parsed = refreshSchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        try {
            const tokens = await authService.refresh(parsed.data.refreshToken);
            return reply.status(200).send(tokens);
        }
        catch (err) {
            return reply.status(401).send({ error: 'Unauthorized', message: err.message });
        }
    });
    // POST /auth/owner-apply (Protected)
    fastify.post('/owner-apply', { preHandler: [auth_1.authenticate] }, async (request, reply) => {
        const ownerApplySchema = zod_1.z.object({
            businessName: zod_1.z.string().min(3),
            documents: zod_1.z.any().optional(),
        });
        const parsed = ownerApplySchema.safeParse(request.body);
        if (!parsed.success) {
            return reply.status(400).send({ error: 'Bad Request', message: parsed.error.format() });
        }
        try {
            const app = await authService.applyForOwner(request.user.id, parsed.data.businessName, parsed.data.documents);
            return reply.status(201).send(app);
        }
        catch (err) {
            return reply.status(400).send({ error: 'Bad Request', message: err.message });
        }
    });
    // GET /auth/me (Protected)
    fastify.get('/me', { preHandler: [auth_1.authenticate] }, async (request, reply) => {
        const user = await prisma_1.prisma.user.findUnique({
            where: { id: request.user.id },
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
