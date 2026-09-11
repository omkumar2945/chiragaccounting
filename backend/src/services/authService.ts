import crypto from 'node:crypto';
import { promisify } from 'node:util';

import jwt from 'jsonwebtoken';

import { env } from '../config/env.js';
import { UserRole } from '../types/securityContext.js';

const scrypt = promisify(crypto.scrypt);
const accessTokenLifetimeSeconds = 15 * 60;
const refreshTokenLifetimeDays = 30;

export type AuthUserType = 'staff' | 'client' | 'business';

export interface AuthUserRecord {
  id: string;
  name: string;
  email: string;
  mobile: string;
  role: UserRole;
  tenantId: string;
  companyId: string;
  branchId: string;
  firmName: string;
  passwordHash: string;
  isActive: boolean;
  mustChangePassword: boolean;
  createdAt: Date;
  lastLoginAt: Date | null;
}

export interface AuthRepository {
  findUserByIdentifier(identifier: string): Promise<AuthUserRecord | null>;
  findUserById(userId: string): Promise<AuthUserRecord | null>;
  recordSuccessfulLogin(userId: string): Promise<void>;
  markEmailVerified(userId: string): Promise<void>;
  updatePassword(userId: string, passwordHash: string): Promise<void>;
  saveRefreshToken(input: {
    tokenHash: string;
    userId: string;
    expiresAt: Date;
  }): Promise<void>;
  consumeRefreshToken(tokenHash: string): Promise<string | null>;
}

export class AuthenticationError extends Error {}

export class AuthService {
  constructor(private readonly repository: AuthRepository) {}

  async login(input: {
    identifier: string;
    password: string;
    userType: AuthUserType;
  }) {
    const identifier = normalizeIdentifier(input.identifier);
    const user = await this.repository.findUserByIdentifier(identifier);
    if (!user || !user.isActive || !roleMatchesUserType(user.role, input.userType)) {
      throw new AuthenticationError('Invalid email/mobile or password.');
    }

    if (!(await verifyPassword(input.password, user.passwordHash))) {
      throw new AuthenticationError('Invalid email/mobile or password.');
    }

    await this.repository.recordSuccessfulLogin(user.id);
    return this.issueSession(user);
  }

  async loginWithVerifiedMobile(input: {
    mobile: string;
    userType: AuthUserType;
  }) {
    const user = await this.repository.findUserByIdentifier(
      normalizeIdentifier(input.mobile),
    );
    if (!user || !user.isActive || !roleMatchesUserType(user.role, input.userType)) {
      throw new AuthenticationError('This mobile number is not authorized for this login.');
    }

    await this.repository.recordSuccessfulLogin(user.id);
    return this.issueSession(user);
  }

  async loginWithVerifiedEmail(input: {
    identifier: string;
    userType: AuthUserType;
  }) {
    const user = await this.findAuthorizedUser(input.identifier, input.userType);
    if (!user) throw new AuthenticationError('This email address is not authorized for this login.');
    await this.repository.markEmailVerified(user.id);
    await this.repository.recordSuccessfulLogin(user.id);
    return this.issueSession(user);
  }

  async requestableUser(identifier: string, userType: AuthUserType) {
    return this.findAuthorizedUser(identifier, userType);
  }

  async resetPassword(identifier: string, password: string) {
    const user = await this.repository.findUserByIdentifier(normalizeIdentifier(identifier));
    if (!user || !user.isActive) throw new AuthenticationError('No active account found for this email.');
    await this.repository.updatePassword(user.id, await hashPassword(password));
  }

  async refresh(refreshToken: string) {
    const userId = await this.repository.consumeRefreshToken(
      hashRefreshToken(refreshToken),
    );
    if (!userId) throw new AuthenticationError('Invalid or expired refresh token.');

    const user = await this.repository.findUserById(userId);
    if (!user?.isActive) {
      throw new AuthenticationError('Invalid or expired refresh token.');
    }
    return this.issueSession(user);
  }

  async revoke(refreshToken: string) {
    await this.repository.consumeRefreshToken(hashRefreshToken(refreshToken));
  }

  private async issueSession(user: AuthUserRecord) {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + accessTokenLifetimeSeconds * 1000);
    const refreshExpiresAt = new Date(
      now.getTime() + refreshTokenLifetimeDays * 24 * 60 * 60 * 1000,
    );
    const accessToken = jwt.sign(
      {
        role: user.role,
        tenant_id: user.tenantId,
        company_id: user.companyId,
        branch_id: user.branchId,
        financial_year: currentFinancialYear(now),
        permissions: user.role === 'super_admin' ? ['*'] : [],
      },
      env.JWT_SECRET,
      { subject: user.id, expiresIn: accessTokenLifetimeSeconds },
    );
    const refreshToken = crypto.randomBytes(48).toString('base64url');
    await this.repository.saveRefreshToken({
      tokenHash: hashRefreshToken(refreshToken),
      userId: user.id,
      expiresAt: refreshExpiresAt,
    });

    return {
      user: toUserResponse(user),
      token: {
        accessToken,
        refreshToken,
        expiresAt: expiresAt.toISOString(),
      },
    };
  }

  private async findAuthorizedUser(identifier: string, userType: AuthUserType) {
    const user = await this.repository.findUserByIdentifier(normalizeIdentifier(identifier));
    return user && user.isActive && roleMatchesUserType(user.role, userType) ? user : null;
  }
}

export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.randomBytes(16);
  const derivedKey = (await scrypt(password, salt, 64)) as Buffer;
  return `scrypt$${salt.toString('base64url')}$${derivedKey.toString('base64url')}`;
}

async function verifyPassword(password: string, encodedHash: string) {
  const [algorithm, saltValue, hashValue] = encodedHash.split('$');
  if (algorithm !== 'scrypt' || !saltValue || !hashValue) return false;
  const expected = Buffer.from(hashValue, 'base64url');
  const actual = (await scrypt(
    password,
    Buffer.from(saltValue, 'base64url'),
    expected.length,
  )) as Buffer;
  return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
}

function hashRefreshToken(token: string) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function normalizeIdentifier(value: string) {
  const trimmed = value.trim();
  if (trimmed.includes('@')) return trimmed.toLowerCase();
  const digits = trimmed.replace(/\D/g, '');
  return digits.length === 12 && digits.startsWith('91') ? digits.slice(2) : digits;
}

function roleMatchesUserType(role: UserRole, userType: AuthUserType) {
  if (userType === 'client') return role === 'client';
  return userType === 'staff' && role !== 'client';
}

function currentFinancialYear(now: Date) {
  const startYear = now.getUTCMonth() >= 3 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
  return `${startYear}-${String(startYear + 1).slice(-2)}`;
}

function toUserResponse(user: AuthUserRecord) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    mobile: user.mobile,
    role: user.role,
    firmId: user.tenantId,
    firmName: user.firmName,
    isActive: user.isActive,
    mustChangePassword: user.mustChangePassword,
    lastLoginAt: user.lastLoginAt?.toISOString() ?? null,
    createdAt: user.createdAt.toISOString(),
  };
}