import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';

import { env } from '../config/env.js';
import { SecurityContext } from '../types/securityContext.js';

declare global {
  namespace Express {
    interface Request {
      securityContext?: SecurityContext;
    }
  }
}

interface TokenShape {
  sub: string;
  role: SecurityContext['role'];
  tenant_id: string;
  company_id: string;
  branch_id: string;
  financial_year: string;
  permissions?: string[];
}

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ message: 'Unauthorized' });
    return;
  }

  const token = header.slice('Bearer '.length);
  try {
    const decoded = jwt.verify(token, env.JWT_SECRET) as TokenShape;
    req.securityContext = {
      userId: decoded.sub,
      role: decoded.role,
      tenantId: decoded.tenant_id,
      companyId: decoded.company_id,
      branchId: decoded.branch_id,
      financialYear: decoded.financial_year,
      permissions: decoded.permissions ?? [],
    };
    next();
  } catch {
    res.status(401).json({ message: 'Invalid token' });
  }
}

export interface AuthRequest extends Request {
  user?: {
    id: number;
    role: string;
  };
}

export function verifyToken(req: AuthRequest, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    res.status(401).json({ message: 'Token not provided.' });
    return;
  }

  try {
    const decoded = jwt.verify(token, env.JWT_SECRET) as { id: number; role: string };
    req.user = decoded;
    next();
  } catch {
    res.status(401).json({ message: 'Invalid token.' });
  }
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
