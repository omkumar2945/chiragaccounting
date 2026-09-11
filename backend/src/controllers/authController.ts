import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import type { ResultSetHeader, RowDataPacket } from 'mysql2';

import { env } from '../config/env.js';
import pool from '../database.js';

interface RegisterBody {
  name?: unknown;
  email?: unknown;
  password?: unknown;
}

interface LoginBody {
  identifier?: unknown;
  emailOrMobile?: unknown;
  email?: unknown;
  mobile?: unknown;
  password?: unknown;
}

function readRegistration(body: RegisterBody) {
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  if (!name || !email || password.length < 8) return null;
  return { name, email, password, role: 'user' };
}

function readLogin(body: LoginBody) {
  const identifier = [body.identifier, body.emailOrMobile, body.email, body.mobile]
    .find((value): value is string => typeof value === 'string' && value.trim().length > 0)
    ?.trim()
    .toLowerCase() ?? '';
  const password = typeof body.password === 'string' ? body.password : '';
  return identifier && password ? { identifier, password } : null;
}

function issueSession(user: RowDataPacket) {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 15 * 60 * 1000);
  const accessToken = jwt.sign(
    { id: user.id, role: user.role },
    env.JWT_SECRET,
    { expiresIn: '15m' },
  );
  const refreshToken = jwt.sign(
    { id: user.id, type: 'refresh' },
    env.JWT_SECRET,
    { expiresIn: '30d' },
  );
  return {
    user: {
      id: String(user.id),
      name: user.name,
      email: user.email,
      mobile: '',
      role: user.role,
      firmId: '',
      firmName: 'Chirag Accounting',
      isActive: true,
      createdAt: now.toISOString(),
    },
    token: { accessToken, refreshToken, expiresAt: expiresAt.toISOString() },
  };
}

export async function register(req: Request, res: Response) {
  const input = readRegistration(req.body as RegisterBody);
  if (!input) {
    res.status(400).json({ message: 'Name, email, and an 8-character password are required.' });
    return;
  }

  try {
    const [existing] = await pool.execute('SELECT id FROM users WHERE email = ? LIMIT 1', [input.email]);
    if (Array.isArray(existing) && existing.length > 0) {
      res.status(409).json({ message: 'Email is already registered.' });
      return;
    }

    const passwordHash = await bcrypt.hash(input.password, 12);
    const [result] = await pool.execute<ResultSetHeader>(
      'INSERT INTO users (name, email, password_hash, role) VALUES (?, ?, ?, ?)',
      [input.name, input.email, passwordHash, input.role],
    );
    res.status(201).json({ message: 'User registered successfully.', userId: result.insertId });
  } catch {
    res.status(500).json({ message: 'Unable to register user.' });
  }
}

export async function login(req: Request, res: Response) {
  const input = readLogin(req.body as LoginBody);
  if (!input) {
    res.status(400).json({ message: 'Email and password are required.' });
    return;
  }

  try {
    const [rows] = await pool.execute<RowDataPacket[]>(
      'SELECT id, name, email, password_hash, role FROM users WHERE email = ? LIMIT 1',
      [input.identifier],
    );
    const user = rows[0];
    if (!user || !(await bcrypt.compare(input.password, user.password_hash))) {
      res.status(401).json({ message: 'Invalid email or password.' });
      return;
    }

    res.json(issueSession(user));
  } catch {
    res.status(500).json({ message: 'Unable to sign in.' });
  }
}

export async function refreshToken(req: Request, res: Response) {
  const token = (req.body as { refreshToken?: unknown }).refreshToken;
  if (typeof token !== 'string' || token.length === 0) {
    res.status(400).json({ message: 'Refresh token is required.' });
    return;
  }

  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as { id?: number; type?: string };
    if (payload.type !== 'refresh' || payload.id == null) throw new Error('Invalid token type');
    const [rows] = await pool.execute<RowDataPacket[]>(
      'SELECT id, name, email, password_hash, role FROM users WHERE id = ? LIMIT 1',
      [payload.id],
    );
    if (!rows[0]) throw new Error('Unknown user');
    res.json(issueSession(rows[0]).token);
  } catch {
    res.status(401).json({ message: 'Invalid or expired refresh token.' });
  }
}

export function logout(_req: Request, res: Response) {
  res.status(204).send();
}