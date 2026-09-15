import { NextFunction, Request, Response } from 'express';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import jwt from 'jsonwebtoken';
import type { RowDataPacket } from 'mysql2';

import { env, firebaseServiceAccount } from '../config/env.js';
import pool from '../database.js';
import { SecurityContext } from '../types/securityContext.js';

declare global {
  namespace Express {
    interface Request {
      securityContext?: SecurityContext;
    }
  }
}

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  return verifyToken(req as AuthRequest, res, next);
}

export interface AuthRequest extends Request {
  user?: {
    id: number;
    role: string;
  };
}

export async function verifyToken(req: AuthRequest, res: Response, next: NextFunction) {
  const token = bearerToken(req);
  if (!token) {
    res.status(401).json({ message: 'Token not provided.' });
    return;
  }

  let decoded: { id?: unknown };
  try {
    decoded = jwt.verify(token, env.JWT_SECRET) as { id?: unknown };
  } catch {
    await authenticateFirebaseBearerToken(token, req, res, next);
    return;
  }

  const userId = typeof decoded.id === 'number' ? decoded.id : Number(decoded.id);
  if (!Number.isSafeInteger(userId) || userId <= 0) {
    res.status(401).json({ message: 'Invalid token.' });
    return;
  }

  try {
    const user = await activeUserById(userId);
    if (!user) {
      res.status(401).json({ message: 'Account is inactive or no longer exists.' });
      return;
    }
    applyAuthenticatedUser(req, user);
    next();
  } catch (error) {
    next(error);
  }
}

async function authenticateFirebaseBearerToken(
  token: string,
  req: AuthRequest,
  res: Response,
  next: NextFunction,
) {
  try {
    const user = await verifyFirebaseToken(token);
    applyAuthenticatedUser(req, user);
    next();
  } catch (error) {
    if (error instanceof AuthenticationFailure) {
      res.status(401).json({ message: 'Invalid token.' });
      return;
    }
    next(error);
  }
}

function bearerToken(req: Request) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length).trim();
  return token || null;
}

function applyAuthenticatedUser(req: AuthRequest, user: { id: number; role: string }) {
  req.user = user;
  setSecurityContext(req, user.id, user.role);
}

class AuthenticationFailure extends Error {}

async function activeUserById(id: number): Promise<{ id: number; role: string } | null> {
  const [rows] = await pool.execute<Array<RowDataPacket & { id: number; role: string }>>(
    'SELECT id, role FROM users WHERE id = ? AND is_active = TRUE LIMIT 1',
    [id],
  );
  return rows[0] ?? null;
}

async function verifyFirebaseToken(token: string): Promise<{ id: number; role: string }> {
  if (getApps().length === 0) {
    initializeApp(firebaseServiceAccount ? { credential: cert(firebaseServiceAccount) } : undefined);
  }

  let decoded: Awaited<ReturnType<ReturnType<typeof getAuth>['verifyIdToken']>>;
  try {
    decoded = await getAuth().verifyIdToken(token);
  } catch {
    throw new AuthenticationFailure();
  }
  const mobile = normalizeMobile(decoded.phone_number ?? '');
  const email = decoded.email_verified ? decoded.email?.trim().toLowerCase() ?? '' : '';
  if (!mobile && !email) throw new AuthenticationFailure();

  const [rows] = await pool.execute<Array<RowDataPacket & { id: number; role: string }>>(
    `SELECT id, role
     FROM users
     WHERE is_active = TRUE AND (mobile = ? OR email = ?)
     LIMIT 1`,
    [mobile, email],
  );
  if (!rows[0]) throw new AuthenticationFailure();
  return rows[0];
}

function normalizeMobile(value: string) {
  const digits = value.replace(/\D/g, '');
  return digits.length === 12 && digits.startsWith('91') ? digits.slice(2) : digits;
}

function setSecurityContext(req: Request, id: number, role: string) {
  req.securityContext = {
    userId: String(id),
    role: role as SecurityContext['role'],
    tenantId: `user-${id}`,
    companyId: `client-${id}`,
    branchId: 'default',
    financialYear: currentFinancialYear(),
    permissions: role === 'super_admin' ? ['*'] : [],
  };
}

function currentFinancialYear() {
  const now = new Date();
  const start = now.getUTCMonth() >= 3 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
  return `${start}-${String(start + 1).slice(-2)}`;
}

export function isSuperAdmin(req: AuthRequest, res: Response, next: NextFunction) {
  if (req.user?.role !== 'super_admin') {
    res.status(403).json({ message: 'Super admin access required.' });
    return;
  }
  next();
}

export function isAdmin(req: AuthRequest, res: Response, next: NextFunction) {
  if (!['super_admin', 'admin'].includes(req.user?.role ?? '')) {
    res.status(403).json({ message: 'Admin access required.' });
    return;
  }
  next();
}
