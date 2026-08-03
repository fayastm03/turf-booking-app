import bcrypt from 'bcryptjs';
import * as jose from 'jose';
import { prisma } from '../../db/prisma';
import { config } from '../../config';
import { SystemRole, ApplicationStatus } from '@prisma/client';

const JWT_SECRET_BYTES = new TextEncoder().encode(config.JWT_SECRET);
const JWT_REFRESH_SECRET_BYTES = new TextEncoder().encode(config.JWT_REFRESH_SECRET);

export async function generateTokens(userId: string, email: string, roles: SystemRole[]) {
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

export async function register(
  email: string,
  password: string,
  name: string,
  phone?: string,
  accountType: 'USER' | 'OWNER' = 'USER',
  businessName?: string,
) {
  const existingUser = await prisma.user.findUnique({ where: { email } });
  if (existingUser) {
    throw new Error('User already exists');
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.$transaction(async (tx) => {
    const created = await tx.user.create({
      data: { email, passwordHash, name, phone, roles: [SystemRole.USER] },
    });

    // Owner accounts remain ordinary users until an administrator approves
    // their application. This prevents self-assigned owner permissions.
    if (accountType === 'OWNER') {
      await tx.ownerApplication.create({
        data: { userId: created.id, businessName: businessName! },
      });
    }
    return created;
  });

  return generateTokens(user.id, user.email, user.roles);
}

export async function login(email: string, password: string, accountType: 'USER' | 'OWNER' = 'USER') {
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    throw new Error('Invalid email or password');
  }

  const isValidPassword = await bcrypt.compare(password, user.passwordHash);
  if (!isValidPassword) {
    throw new Error('Invalid email or password');
  }

  if (user.status === 'SUSPENDED') {
    throw new Error('User account is suspended');
  }

  if (accountType === 'OWNER' && !user.roles.includes(SystemRole.OWNER)) {
    const application = await prisma.ownerApplication.findUnique({ where: { userId: user.id } });
    if (application?.status === ApplicationStatus.PENDING) {
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

export async function refresh(token: string) {
  try {
    const { payload } = await jose.jwtVerify(token, JWT_REFRESH_SECRET_BYTES);
    const userId = payload.sub as string;

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.status === 'SUSPENDED') {
      throw new Error('User not found or suspended');
    }

    return generateTokens(user.id, user.email, user.roles);
  } catch (err) {
    throw new Error('Invalid or expired refresh token');
  }
}

export async function applyForOwner(userId: string, businessName: string, documents?: any) {
  const existingApp = await prisma.ownerApplication.findUnique({ where: { userId } });
  if (existingApp) {
    if (existingApp.status === ApplicationStatus.PENDING) {
      throw new Error('An application is already pending review');
    }
    if (existingApp.status === ApplicationStatus.APPROVED) {
      throw new Error('You are already registered as an owner');
    }
  }

  return prisma.ownerApplication.upsert({
    where: { userId },
    update: {
      businessName,
      documents: documents || null,
      status: ApplicationStatus.PENDING,
    },
    create: {
      userId,
      businessName,
      documents: documents || null,
      status: ApplicationStatus.PENDING,
    },
  });
}
