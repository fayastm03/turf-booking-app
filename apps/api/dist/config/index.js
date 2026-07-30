"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
const zod_1 = require("zod");
dotenv_1.default.config();
const configSchema = zod_1.z.object({
    PORT: zod_1.z.coerce.number().default(3000),
    DATABASE_URL: zod_1.z.string(),
    REDIS_URL: zod_1.z.string().default('redis://localhost:6379'),
    JWT_SECRET: zod_1.z.string().min(8),
    JWT_REFRESH_SECRET: zod_1.z.string().min(8),
    RAZORPAY_KEY_ID: zod_1.z.string(),
    RAZORPAY_KEY_SECRET: zod_1.z.string(),
    RAZORPAY_WEBHOOK_SECRET: zod_1.z.string(),
});
const result = configSchema.safeParse(process.env);
if (!result.success) {
    console.error('❌ Invalid environment configuration:', result.error.format());
    process.exit(1);
}
exports.config = result.data;
