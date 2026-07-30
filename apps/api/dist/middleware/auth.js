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
exports.authenticate = authenticate;
exports.requireRoles = requireRoles;
const jose = __importStar(require("jose"));
const config_1 = require("../config");
const JWT_SECRET_BYTES = new TextEncoder().encode(config_1.config.JWT_SECRET);
async function authenticate(request, reply) {
    try {
        const authHeader = request.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return reply.status(401).send({ error: 'Unauthorized', message: 'Missing or invalid authorization header' });
        }
        const token = authHeader.split(' ')[1];
        const { payload } = await jose.jwtVerify(token, JWT_SECRET_BYTES);
        request.user = {
            id: payload.sub,
            email: payload.email,
            roles: payload.roles,
        };
    }
    catch (err) {
        return reply.status(401).send({ error: 'Unauthorized', message: 'Invalid or expired token' });
    }
}
function requireRoles(roles) {
    return async (request, reply) => {
        if (!request.user) {
            return reply.status(401).send({ error: 'Unauthorized', message: 'User not authenticated' });
        }
        const hasRole = request.user.roles.some((r) => roles.includes(r));
        if (!hasRole) {
            return reply.status(403).send({ error: 'Forbidden', message: 'Insufficient permissions' });
        }
    };
}
