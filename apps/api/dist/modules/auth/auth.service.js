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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateTokens = generateTokens;
exports.register = register;
exports.login = login;
exports.refresh = refresh;
exports.applyForOwner = applyForOwner;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const jose = __importStar(require("jose"));
const prisma_1 = require("../../db/prisma");
const config_1 = require("../../config");
const client_1 = require("@prisma/client");
const JWT_SECRET_BYTES = new TextEncoder().encode(config_1.config.JWT_SECRET);
const JWT_REFRESH_SECRET_BYTES = new TextEncoder().encode(config_1.config.JWT_REFRESH_SECRET);
async function generateTokens(userId, email, roles) {
    const accessToken = await new jose.SignJWT({ email, roles })
        .setProtectedHeader({ alg: 'HS256' })
        .setSubject(userId)
        .setIssuedAt()
        .setExpirationTime('15m')
        .sign(JWT_SECRET_BYTES);
    const refreshToken = await new jose.SignJWT({})
        .setProtectedHeader({ alg: 'HS256' })
        .setSubject(userId)
        .setIssuedAt()
        .setExpirationTime('7d')
        .sign(JWT_REFRESH_SECRET_BYTES);
    return { accessToken, refreshToken };
}
async function register(email, password, name, phone, accountType = 'USER', businessName) {
    const existingUser = await prisma_1.prisma.user.findUnique({ where: { email } });
    if (existingUser) {
        throw new Error('User already exists');
    }
    const passwordHash = await bcryptjs_1.default.hash(password, 10);
    const user = await prisma_1.prisma.$transaction(async (tx) => {
        const created = await tx.user.create({
            data: { email, passwordHash, name, phone, roles: [client_1.SystemRole.USER] },
        });
        // Owner accounts remain ordinary users until an administrator approves
        // their application. This prevents self-assigned owner permissions.
        if (accountType === 'OWNER') {
            await tx.ownerApplication.create({
                data: { userId: created.id, businessName: businessName },
            });
        }
        return created;
    });
    return generateTokens(user.id, user.email, user.roles);
}
async function login(email, password, accountType = 'USER') {
    const user = await prisma_1.prisma.user.findUnique({ where: { email } });
    if (!user) {
        throw new Error('Invalid email or password');
    }
    const isValidPassword = await bcryptjs_1.default.compare(password, user.passwordHash);
    if (!isValidPassword) {
        throw new Error('Invalid email or password');
    }
    if (user.status === 'SUSPENDED') {
        throw new Error('User account is suspended');
    }
    if (accountType === 'OWNER' && !user.roles.includes(client_1.SystemRole.OWNER)) {
        const application = await prisma_1.prisma.ownerApplication.findUnique({ where: { userId: user.id } });
        if (application?.status === client_1.ApplicationStatus.PENDING) {
            throw new Error('Your owner account is awaiting approval');
        }
        throw new Error('This email is not an approved turf-owner account');
    }
    const tokens = await generateTokens(user.id, user.email, user.roles);
    return {
        ...tokens,
        user: {
            id: user.id,
            email: user.email,
            name: user.name,
            roles: user.roles,
        },
    };
}
async function refresh(token) {
    try {
        const { payload } = await jose.jwtVerify(token, JWT_REFRESH_SECRET_BYTES);
        const userId = payload.sub;
        const user = await prisma_1.prisma.user.findUnique({ where: { id: userId } });
        if (!user || user.status === 'SUSPENDED') {
            throw new Error('User not found or suspended');
        }
        return generateTokens(user.id, user.email, user.roles);
    }
    catch (err) {
        throw new Error('Invalid or expired refresh token');
    }
}
async function applyForOwner(userId, businessName, documents) {
    const existingApp = await prisma_1.prisma.ownerApplication.findUnique({ where: { userId } });
    if (existingApp) {
        if (existingApp.status === client_1.ApplicationStatus.PENDING) {
            throw new Error('An application is already pending review');
        }
        if (existingApp.status === client_1.ApplicationStatus.APPROVED) {
            throw new Error('You are already registered as an owner');
        }
    }
    return prisma_1.prisma.ownerApplication.upsert({
        where: { userId },
        update: {
            businessName,
            documents: documents || null,
            status: client_1.ApplicationStatus.PENDING,
        },
        create: {
            userId,
            businessName,
            documents: documents || null,
            status: client_1.ApplicationStatus.PENDING,
        },
    });
}
