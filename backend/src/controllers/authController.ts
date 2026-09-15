import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import jwt from 'jsonwebtoken';
import type { ResultSetHeader, RowDataPacket } from 'mysql2';
import { createHash, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';

import { env, firebaseServiceAccount } from '../config/env.js';
import pool from '../database.js';
import { AuthRequest } from '../middleware/auth.js';
import { isValidPassword, passwordPolicyMessage } from '../security/passwordPolicy.js';
import { deliverEmailOtp } from '../services/emailOtpService.js';
import {
  decideImportIdentity,
  importValidationMessage,
  parseImportedClient,
  type ImportedClient,
  type ExistingUserIdentity,
} from '../services/clientImportValidation.js';
import { recordClientDataChange } from '../services/clientDataAudit.js';

interface RegisterBody {
  name?: unknown;
  fullName?: unknown;
  email?: unknown;
  mobile?: unknown;
  phone?: unknown;
  phoneNumber?: unknown;
  password?: unknown;
  firmName?: unknown;
  companyName?: unknown;
  role?: unknown;
  gstin?: unknown;
  pan?: unknown;
  state?: unknown;
  city?: unknown;
}

interface SelfRegistrationInput {
  name: string;
  email: string;
  mobile: string;
  password: string;
  firmName: string;
  gstin: string;
  pan: string;
  state: string;
  city: string;
}

interface LoginBody {
  identifier?: unknown;
  emailOrMobile?: unknown;
  email?: unknown;
  mobile?: unknown;
  password?: unknown;
}

interface FirebasePasswordChangeBody {
  idToken?: unknown;
  newPassword?: unknown;
}

interface FirebasePhoneLoginBody {
  idToken?: unknown;
  userType?: unknown;
}

interface PasswordResetRequestBody {
  identifier?: unknown;
  emailOrMobile?: unknown;
  email?: unknown;
  mobile?: unknown;
}

interface PasswordResetOtpVerificationBody {
  challengeId?: unknown;
  otp?: unknown;
}

interface ResetPasswordBody {
  resetToken?: unknown;
  newPassword?: unknown;
}

interface PasswordResetChallenge {
  userId: number;
  otpHash: Buffer;
  expiresAt: number;
  attemptsRemaining: number;
}

interface PasswordResetAuthorization {
  userId: number;
  expiresAt: number;
  attemptsRemaining: number;
}

const passwordResetLifetimeMs = 10 * 60 * 1000;
const passwordResetOtpAttempts = 5;
const passwordResetSubmissionAttempts = 3;
const passwordResetChallenges = new Map<string, PasswordResetChallenge>();
const passwordResetAuthorizations = new Map<string, PasswordResetAuthorization>();

function firebaseAuth() {
  if (getApps().length === 0) {
    initializeApp(
      firebaseServiceAccount
          ? { credential: cert(firebaseServiceAccount) }
          : undefined,
    );
  }
  return getAuth();
}

function normalizeMobile(value: string) {
  const digits = value.replace(/\D/g, '');
  return digits.length === 12 && digits.startsWith('91') ? digits.slice(2) : digits;
}

function registrationText(...values: unknown[]) {
  for (const value of values) {
    if (typeof value !== 'string') continue;
    const normalized = value.trim();
    if (normalized) return normalized;
  }
  return '';
}

function readRegistration(body: RegisterBody): SelfRegistrationInput | null {
  const requestedRole = registrationText(body.role).toLowerCase();
  if (requestedRole && requestedRole !== 'client') return null;

  const name = registrationText(body.name, body.fullName);
  const email = registrationText(body.email).toLowerCase();
  const mobile = normalizeMobile(registrationText(
    body.mobile,
    body.phone,
    body.phoneNumber,
  ));
  const password = typeof body.password === 'string' ? body.password : '';
  const firmName = registrationText(body.firmName, body.companyName);
  const gstin = registrationText(body.gstin).toUpperCase();
  const pan = registrationText(body.pan).toUpperCase();
  const state = registrationText(body.state);
  const city = registrationText(body.city);
  if (
    !name ||
    name.length > 200 ||
    !/^\S+@\S+\.\S+$/.test(email) ||
    email.length > 320 ||
    !/^\d{10}$/.test(mobile) ||
    !firmName ||
    firmName.length > 200 ||
    !isValidPassword(password) ||
    gstin.length > 15 ||
    pan.length > 20 ||
    state.length > 120 ||
    city.length > 120
  ) {
    return null;
  }
  return { name, email, mobile, password, firmName, gstin, pan, state, city };
}

function readLogin(body: LoginBody) {
  const identifier = [body.identifier, body.emailOrMobile, body.email, body.mobile]
    .find((value): value is string => typeof value === 'string' && value.trim().length > 0)
    ?.trim()
    .toLowerCase() ?? '';
  const password = typeof body.password === 'string' ? body.password : '';
  return identifier && password ? { identifier, password } : null;
}

function readPasswordResetIdentifier(body: PasswordResetRequestBody) {
  const rawIdentifier = [body.identifier, body.emailOrMobile, body.email, body.mobile]
    .find((value): value is string => typeof value === 'string' && value.trim().length > 0)
    ?.trim() ?? '';
  if (!rawIdentifier) return null;
  if (rawIdentifier.includes('@')) {
    const email = rawIdentifier.toLowerCase();
    return /^\S+@\S+\.\S+$/.test(email) && email.length <= 320 ? email : null;
  }
  const mobile = normalizeMobile(rawIdentifier);
  return /^\d{10}$/.test(mobile) ? mobile : null;
}

function readPasswordResetOtpVerification(body: PasswordResetOtpVerificationBody) {
  const challengeId = typeof body.challengeId === 'string' ? body.challengeId.trim() : '';
  const otp = typeof body.otp === 'string' ? body.otp.trim() : '';
  return /^[A-Za-z0-9_-]{32,}$/.test(challengeId) && /^\d{6}$/.test(otp)
    ? { challengeId, otp }
    : null;
}

function readResetPasswordSubmission(body: ResetPasswordBody) {
  const resetToken = typeof body.resetToken === 'string' ? body.resetToken.trim() : '';
  const newPassword = typeof body.newPassword === 'string' ? body.newPassword : '';
  return /^[A-Za-z0-9_-]{32,}$/.test(resetToken)
    ? { resetToken, newPassword }
    : null;
}

function hashPasswordResetValue(value: string) {
  return createHash('sha256').update(value).digest();
}

function passwordResetOtpMatches(expectedHash: Buffer, otp: string) {
  const actualHash = hashPasswordResetValue(otp);
  return actualHash.length === expectedHash.length && timingSafeEqual(actualHash, expectedHash);
}

function purgeExpiredPasswordResetRecords(now = Date.now()) {
  for (const [challengeId, challenge] of passwordResetChallenges) {
    if (challenge.expiresAt <= now) passwordResetChallenges.delete(challengeId);
  }
  for (const [tokenHash, authorization] of passwordResetAuthorizations) {
    if (authorization.expiresAt <= now) passwordResetAuthorizations.delete(tokenHash);
  }
}

function clearPasswordResetRecordsForUser(userId: number) {
  for (const [challengeId, challenge] of passwordResetChallenges) {
    if (challenge.userId === userId) passwordResetChallenges.delete(challengeId);
  }
  for (const [tokenHash, authorization] of passwordResetAuthorizations) {
    if (authorization.userId === userId) passwordResetAuthorizations.delete(tokenHash);
  }
}

function databaseBoolean(value: unknown, defaultValue: boolean) {
  if (value == null) return defaultValue;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (['0', 'false', 'off'].includes(normalized)) return false;
    if (['1', 'true', 'on'].includes(normalized)) return true;
  }
  return defaultValue;
}

function canIssueClientSession(user: RowDataPacket) {
  if (user.role !== 'client') return true;
  return databaseBoolean(user.login_enabled, true) && !databaseBoolean(user.account_locked, false);
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
      mobile: String(user.mobile ?? ''),
      role: user.role,
      firmId: '',
      firmName: user.firm_name ?? 'Chirag Accounting',
      isActive: Boolean(user.is_active ?? true),
      accountOrigin: user.account_origin,
      clientStatus: user.client_status,
      loginStatus: user.login_status,
      mustChangePassword: Boolean(user.must_change_password),
      createdAt: user.created_at
        ? new Date(user.created_at).toISOString()
        : now.toISOString(),
      lastLoginAt: user.last_login_at
        ? new Date(user.last_login_at).toISOString()
        : null,
    },
    token: { accessToken, refreshToken, expiresAt: expiresAt.toISOString() },
  };
}

export async function register(req: Request, res: Response) {
  const input = readRegistration(req.body as RegisterBody);
  if (!input) {
    res.status(400).json({
      message: 'A client registration requires name, email, 10-digit mobile, firm name, and a valid password.',
    });
    return;
  }

  const connection = await pool.getConnection();
  let transactionOpen = false;
  try {
    await connection.beginTransaction();
    transactionOpen = true;
    const [existing] = await connection.execute<RowDataPacket[]>(
      'SELECT id FROM users WHERE email = ? OR mobile = ? LIMIT 1 FOR UPDATE',
      [input.email, input.mobile],
    );
    if (existing.length > 0) {
      await connection.rollback();
      transactionOpen = false;
      res.status(409).json({ message: 'Email is already registered.' });
      return;
    }

    const passwordHash = await bcrypt.hash(input.password, 12);
    const [result] = await connection.execute<ResultSetHeader>(
      `INSERT INTO users (
         name, email, mobile, firm_name, password_hash, role, account_origin,
         client_status, login_status, is_active, must_change_password
       ) VALUES (?, ?, ?, ?, ?, 'client', 'selfRegistered', 'pendingApproval', 'loginNotCreated', FALSE, FALSE)`,
      [input.name, input.email, input.mobile, input.firmName, passwordHash],
    );
    const clientId = result.insertId;
    await connection.execute(
      `INSERT INTO client_profiles (
         client_id, legal_name, gstin, pan, state, city, created_by, updated_by
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [clientId, input.firmName, input.gstin, input.pan, input.state, input.city, clientId, clientId],
    );
    await connection.execute(
      `INSERT INTO client_compliance (
         client_id, gst_registration_type, accounting_enabled, gst_enabled,
         services_json, service_periods_json, created_by, updated_by
       ) VALUES (?, 'unregistered', TRUE, FALSE, JSON_ARRAY(), JSON_ARRAY(), ?, ?)`,
      [clientId, clientId, clientId],
    );
    await connection.execute(
      `INSERT INTO client_access_policies (
         client_id, modules_json, dashboard_widgets_json, document_hub_access_json,
         created_by, updated_by
       ) VALUES (?, JSON_OBJECT(), JSON_OBJECT(), JSON_OBJECT(), ?, ?)`,
      [clientId, clientId, clientId],
    );
    await connection.execute(
      `INSERT INTO client_workspaces (client_id, created_by, updated_by)
       VALUES (?, ?, ?)`,
      [clientId, clientId, clientId],
    );
    await recordClientDataChange(connection, clientId, clientId, 'client.selfRegistered', {
      name: input.name,
      email: input.email,
      mobile: input.mobile,
      firmName: input.firmName,
    });
    await connection.commit();
    transactionOpen = false;
    res.status(201).json({
      message: 'Registration received. Admin approval is required before sign-in.',
      userId: clientId,
    });
  } catch (error) {
    if (transactionOpen) await connection.rollback();
    if ((error as { code?: unknown }).code === 'ER_DUP_ENTRY') {
      res.status(409).json({ message: 'An account already exists with this email or mobile.' });
      return;
    }
    res.status(500).json({ message: 'Unable to register user.' });
  } finally {
    connection.release();
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
      `SELECT u.id, u.name, u.email, u.mobile, u.firm_name, u.password_hash, u.role,
              u.account_origin, u.client_status, u.login_status, u.is_active,
              u.must_change_password, u.created_at, u.last_login_at,
              policy.login_enabled, policy.account_locked
       FROM users u
       LEFT JOIN client_access_policies policy ON policy.client_id = u.id
       WHERE u.is_active = TRUE AND (u.email = ? OR u.mobile = ?)
       LIMIT 1`,
      [input.identifier, input.identifier],
    );
    const user = rows[0];
    if (!user || !(await bcrypt.compare(input.password, user.password_hash))) {
      res.status(401).json({ message: 'Invalid email or password.' });
      return;
    }
    if (!canIssueClientSession(user)) {
      res.status(401).json({ message: 'Invalid email or password.' });
      return;
    }

    res.json(issueSession(await recordSuccessfulLogin(user)));
  } catch {
    res.status(500).json({ message: 'Unable to sign in.' });
  }
}

export async function forgotPassword(req: Request, res: Response) {
  const identifier = readPasswordResetIdentifier(req.body as PasswordResetRequestBody);
  if (!identifier) {
    res.status(400).json({ message: 'Enter a valid registered email or 10-digit mobile number.' });
    return;
  }

  purgeExpiredPasswordResetRecords();
  const challengeId = randomBytes(32).toString('base64url');
  try {
    const [rows] = await pool.execute<RowDataPacket[]>(
      `SELECT id, email
       FROM users
       WHERE is_active = TRUE AND (email = ? OR mobile = ?)
       LIMIT 1`,
      [identifier, identifier],
    );
    const user = rows[0];
    const userId = Number(user?.id);
    const email = typeof user?.email === 'string' ? user.email.trim().toLowerCase() : '';
    if (Number.isSafeInteger(userId) && userId > 0 && email) {
      const otp = randomInt(100000, 1000000).toString();
      try {
        await deliverEmailOtp(email, otp, 'password_reset');
        clearPasswordResetRecordsForUser(userId);
        passwordResetChallenges.set(challengeId, {
          userId,
          otpHash: hashPasswordResetValue(otp),
          expiresAt: Date.now() + passwordResetLifetimeMs,
          attemptsRemaining: passwordResetOtpAttempts,
        });
      } catch {}
    }
    res.status(202).json({
      message: 'If an active account matches that contact detail, a password reset code has been sent.',
      challengeId,
    });
  } catch (error) {
    res.status(500).json({ message: 'Password reset is temporarily unavailable.' });
  }
}

export function verifyPasswordResetOtp(req: Request, res: Response) {
  const input = readPasswordResetOtpVerification(
    req.body as PasswordResetOtpVerificationBody,
  );
  if (!input) {
    res.status(400).json({ message: 'A reset challenge and 6-digit verification code are required.' });
    return;
  }

  purgeExpiredPasswordResetRecords();
  const challenge = passwordResetChallenges.get(input.challengeId);
  if (!challenge || challenge.expiresAt <= Date.now() || challenge.attemptsRemaining <= 0) {
    passwordResetChallenges.delete(input.challengeId);
    res.status(401).json({ message: 'Invalid or expired verification code.' });
    return;
  }

  challenge.attemptsRemaining -= 1;
  if (!passwordResetOtpMatches(challenge.otpHash, input.otp)) {
    if (challenge.attemptsRemaining <= 0) passwordResetChallenges.delete(input.challengeId);
    res.status(401).json({ message: 'Invalid or expired verification code.' });
    return;
  }

  passwordResetChallenges.delete(input.challengeId);
  const resetToken = randomBytes(48).toString('base64url');
  const expiresAt = Date.now() + passwordResetLifetimeMs;
  passwordResetAuthorizations.set(hashPasswordResetValue(resetToken).toString('hex'), {
    userId: challenge.userId,
    expiresAt,
    attemptsRemaining: passwordResetSubmissionAttempts,
  });
  res.json({ resetToken, expiresAt: new Date(expiresAt).toISOString() });
}

export async function resetPassword(req: Request, res: Response) {
  const input = readResetPasswordSubmission(req.body as ResetPasswordBody);
  if (!input) {
    res.status(401).json({ message: 'Invalid or expired password reset authorization.' });
    return;
  }

  purgeExpiredPasswordResetRecords();
  const tokenHash = hashPasswordResetValue(input.resetToken).toString('hex');
  const authorization = passwordResetAuthorizations.get(tokenHash);
  if (!authorization || authorization.expiresAt <= Date.now() || authorization.attemptsRemaining <= 0) {
    passwordResetAuthorizations.delete(tokenHash);
    res.status(401).json({ message: 'Invalid or expired password reset authorization.' });
    return;
  }
  if (!isValidPassword(input.newPassword)) {
    authorization.attemptsRemaining -= 1;
    if (authorization.attemptsRemaining <= 0) passwordResetAuthorizations.delete(tokenHash);
    res.status(400).json({ message: passwordPolicyMessage });
    return;
  }

  passwordResetAuthorizations.delete(tokenHash);
  const passwordHash = await bcrypt.hash(input.newPassword, 12);
  const connection = await pool.getConnection();
  let transactionOpen = false;
  try {
    await connection.beginTransaction();
    transactionOpen = true;
    const [rows] = await connection.execute<RowDataPacket[]>(
      'SELECT id, role FROM users WHERE id = ? AND is_active = TRUE FOR UPDATE',
      [authorization.userId],
    );
    const user = rows[0];
    if (!user) {
      await connection.rollback();
      transactionOpen = false;
      res.status(401).json({ message: 'Invalid or expired password reset authorization.' });
      return;
    }

    await connection.execute<ResultSetHeader>(
      `UPDATE users
       SET password_hash = ?, must_change_password = FALSE,
           login_status = CASE WHEN role = 'client' THEN 'passwordChanged' ELSE login_status END,
           identity_revision = CASE
             WHEN role = 'client' THEN identity_revision + 1
             ELSE identity_revision
           END,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [passwordHash, authorization.userId],
    );
    if (user.role === 'client') {
      await recordClientDataChange(
        connection,
        authorization.userId,
        authorization.userId,
        'identity.passwordReset',
        {},
      );
    }
    await connection.commit();
    transactionOpen = false;
    res.status(204).send();
  } catch {
    if (transactionOpen) await connection.rollback();
    res.status(500).json({ message: 'Unable to reset password.' });
  } finally {
    connection.release();
  }
}

export async function loginWithFirebasePhone(req: Request, res: Response) {
  const body = req.body as FirebasePhoneLoginBody;
  const idToken = typeof body.idToken === 'string' ? body.idToken.trim() : '';
  const userType = typeof body.userType === 'string' ? body.userType : 'staff';
  if (!idToken || !['staff', 'client', 'business'].includes(userType)) {
    res.status(400).json({ message: 'A Firebase ID token and valid user type are required.' });
    return;
  }

  try {
    const firebaseUser = await firebaseAuth().verifyIdToken(idToken);
    const mobile = normalizeMobile(firebaseUser.phone_number ?? '');
    const email = firebaseUser.email_verified ? firebaseUser.email?.trim().toLowerCase() ?? '' : '';
    if (!mobile && !email) {
      res.status(401).json({ message: 'Firebase did not verify a mobile number or email address.' });
      return;
    }

    const [rows] = await pool.execute<RowDataPacket[]>(
      `SELECT u.id, u.name, u.email, u.mobile, u.firm_name, u.role, u.account_origin,
              u.client_status, u.login_status, u.is_active, u.must_change_password,
              u.created_at, u.last_login_at, policy.login_enabled, policy.account_locked
       FROM users u
       LEFT JOIN client_access_policies policy ON policy.client_id = u.id
       WHERE u.is_active = TRUE AND (u.mobile = ? OR u.email = ?)
       LIMIT 1`,
      [mobile, email],
    );
    const user = rows[0];
    const isClientLogin = userType === 'client';
    if (!user || (isClientLogin ? user.role !== 'client' : user.role === 'client')) {
      res.status(401).json({ message: 'No authorized active account matches this Firebase identity.' });
      return;
    }
    if (!canIssueClientSession(user)) {
      res.status(401).json({ message: 'No authorized active account matches this Firebase identity.' });
      return;
    }

    res.json(issueSession(await recordSuccessfulLogin(user)));
  } catch {
    res.status(401).json({ message: 'Firebase token verification failed.' });
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
      `SELECT u.id, u.name, u.email, u.mobile, u.firm_name, u.password_hash, u.role,
              u.account_origin, u.client_status, u.login_status, u.is_active,
              u.must_change_password, u.created_at, u.last_login_at,
              policy.login_enabled, policy.account_locked
       FROM users u
       LEFT JOIN client_access_policies policy ON policy.client_id = u.id
       WHERE u.id = ? AND u.is_active = TRUE LIMIT 1`,
      [payload.id],
    );
    if (!rows[0] || !canIssueClientSession(rows[0])) throw new Error('Unknown user');
    res.json(issueSession(rows[0]).token);
  } catch {
    res.status(401).json({ message: 'Invalid or expired refresh token.' });
  }
}

export async function changePasswordWithFirebaseOtp(
  req: AuthRequest,
  res: Response,
) {
  const body = req.body as FirebasePasswordChangeBody;
  const idToken = typeof body.idToken === 'string' ? body.idToken.trim() : '';
  const newPassword = typeof body.newPassword === 'string' ? body.newPassword : '';
  if (!idToken || !isValidPassword(newPassword)) {
    res.status(400).json({ message: `A Firebase OTP verification is required. ${passwordPolicyMessage}` });
    return;
  }
  if (req.user?.id == null) {
    res.status(401).json({ message: 'A signed-in session is required.' });
    return;
  }

  try {
    const firebaseUser = await firebaseAuth().verifyIdToken(idToken);
    const verifiedMobile = normalizeMobile(firebaseUser.phone_number ?? '');
    if (!/^\d{10}$/.test(verifiedMobile)) {
      res.status(401).json({ message: 'Firebase did not verify a valid mobile number.' });
      return;
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      const [rows] = await connection.execute<RowDataPacket[]>(
        'SELECT id, mobile, role FROM users WHERE id = ? AND is_active = TRUE FOR UPDATE',
        [req.user.id],
      );
      const user = rows[0];
      if (!user || normalizeMobile(String(user.mobile ?? '')) !== verifiedMobile) {
        await connection.rollback();
        res.status(403).json({ message: 'The verified mobile number does not belong to this account.' });
        return;
      }

      await connection.execute<ResultSetHeader>(
        `UPDATE users
         SET password_hash = ?, must_change_password = FALSE,
             login_status = CASE WHEN role = 'client' THEN 'passwordChanged' ELSE login_status END,
             last_login_at = CURRENT_TIMESTAMP,
             identity_revision = CASE
               WHEN role = 'client' THEN identity_revision + 1
               ELSE identity_revision
             END
         WHERE id = ?`,
        [passwordHash, req.user.id],
      );
      if (user.role === 'client') {
        await recordClientDataChange(
          connection,
          req.user.id,
          req.user.id,
          'identity.passwordChanged',
          {},
        );
      }
      await connection.commit();
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
    res.status(204).send();
  } catch {
    res.status(401).json({ message: 'Firebase OTP verification failed. Please request a new OTP.' });
  }
}

export function logout(_req: Request, res: Response) {
  res.status(204).send();
}

interface AdminClientImportBody {
  clients?: unknown;
}

export async function listClients(_req: Request, res: Response) {
  try {
    const [rows] = await pool.execute<RowDataPacket[]>(
            `SELECT u.id, u.name, u.email, u.mobile, u.firm_name, u.role, u.account_origin,
              u.client_status, u.login_status, u.is_active, u.must_change_password, u.identity_revision,
              u.created_at, u.last_login_at, p.gstin, p.pan, p.state, p.city, p.pincode,
              c.gst_registration_type, c.accounting_enabled, c.gst_enabled, c.services_json
             FROM users u
             LEFT JOIN client_profiles p ON p.client_id = u.id
             LEFT JOIN client_compliance c ON c.client_id = u.id
             WHERE u.role = 'client'
             ORDER BY u.created_at DESC`,
    );
    res.json({
      data: {
        clients: rows.map((user) => ({
          id: String(user.id),
          name: user.name,
          email: user.email,
          mobile: user.mobile,
          role: user.role,
          firmId: `client-${user.id}`,
          firmName: user.firm_name,
          accountOrigin: user.account_origin,
          clientStatus: user.client_status,
          loginStatus: user.login_status,
          isActive: Boolean(user.is_active),
          mustChangePassword: Boolean(user.must_change_password),
          version: Number(user.identity_revision ?? 1),
          gstin: user.gstin ?? '',
          pan: user.pan ?? '',
          state: user.state ?? '',
          city: user.city ?? '',
          pincode: user.pincode ?? '',
          gstRegistrationType: user.gst_registration_type ?? 'unregistered',
          accountingEnabled: user.accounting_enabled == null ? true : Boolean(user.accounting_enabled),
          gstEnabled: Boolean(user.gst_enabled),
          services: parseJsonArray(user.services_json),
          createdAt: new Date(user.created_at).toISOString(),
          lastLoginAt: user.last_login_at ? new Date(user.last_login_at).toISOString() : null,
        })),
      },
    });
  } catch {
    res.status(500).json({ message: 'Unable to load clients.' });
  }
}

export async function listStaff(_req: Request, res: Response) {
  try {
    const [rows] = await pool.execute<RowDataPacket[]>(
      `SELECT id, name, email, mobile, firm_name, role, is_active, must_change_password,
              created_at, last_login_at
       FROM users
       WHERE role IN (
         'super_admin', 'admin', 'partner', 'manager', 'firm_admin', 'business_owner',
         'business', 'accountant', 'data_entry_operator', 'operator', 'staff', 'checker',
         'ca', 'auditor'
       )
       ORDER BY name ASC, created_at ASC`,
    );
    res.json({
      data: {
        staff: rows.map((user) => ({
          id: String(user.id),
          name: user.name,
          email: user.email,
          mobile: user.mobile,
          role: user.role,
          firmId: `user-${user.id}`,
          firmName: user.firm_name,
          isActive: Boolean(user.is_active),
          mustChangePassword: Boolean(user.must_change_password),
          createdAt: new Date(user.created_at).toISOString(),
          lastLoginAt: user.last_login_at
              ? new Date(user.last_login_at).toISOString()
              : null,
        })),
      },
    });
  } catch {
    res.status(500).json({ message: 'Unable to load staff users.' });
  }
}

export async function importClients(req: AuthRequest, res: Response) {
  const body = req.body as AdminClientImportBody;
  if (!Array.isArray(body.clients) || body.clients.length === 0) {
    res.status(400).json({ message: 'At least one client is required.' });
    return;
  }
  if (req.user?.id == null) {
    res.status(401).json({ message: 'A signed-in administrator is required.' });
    return;
  }

  let created = 0;
  let updated = 0;
  let skipped = 0;
  const errors: string[] = [];
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    for (let index = 0; index < body.clients.length; index++) {
      const parsed = parseImportedClient(body.clients[index]);
      if (!parsed.success) {
        skipped++;
        errors.push(`Row ${index + 1}: ${importValidationMessage(parsed.error)}`);
        continue;
      }

      const client = parsed.data;
      const [existing] = await connection.execute<Array<RowDataPacket & ExistingUserIdentity>>(
        'SELECT id, email, mobile, role FROM users WHERE email = ? OR mobile = ?',
        [client.email, client.mobile],
      );
      const decision = decideImportIdentity(client, existing);
      if (decision.action === 'conflict') {
        skipped++;
        errors.push(`Row ${index + 1}: ${decision.reason}`);
        await recordImportReconciliation(connection, client, null, 'conflict', decision.reason);
        continue;
      }

      if (decision.action === 'create') {
        const [result] = await connection.execute<ResultSetHeader>(
          `INSERT INTO users (
             name, email, mobile, firm_name, password_hash, role, account_origin,
             client_status, login_status, is_active, must_change_password
           ) VALUES (?, ?, ?, ?, '', 'client', 'imported', 'notOnboarded', 'loginNotCreated', 0, 1)`,
          [client.name, client.email, client.mobile, client.firmName],
        );
        await upsertImportedClientData(connection, result.insertId, client, req.user.id);
        await recordImportReconciliation(connection, client, result.insertId, 'applied', '');
        await recordClientDataChange(connection, result.insertId, req.user.id, 'client.imported', client);
        created++;
      } else {
        await upsertImportedClientData(connection, decision.userId, client, req.user.id);
        await recordImportReconciliation(connection, client, decision.userId, 'applied', '');
        await recordClientDataChange(connection, decision.userId, req.user.id, 'client.imported', client);
        updated++;
      }
    }
    await connection.commit();
    res.status(created + updated > 0 ? 201 : 422).json({ created, updated, skipped, errors });
  } catch {
    await connection.rollback();
    res.status(500).json({ message: 'Unable to import clients.' });
  } finally {
    connection.release();
  }
}

function parseJsonArray(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(String);
  if (typeof value !== 'string') return [];
  try {
    const parsed: unknown = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.map(String) : [];
  } catch {
    return [];
  }
}

async function upsertImportedClientData(
  connection: Awaited<ReturnType<typeof pool.getConnection>>,
  clientId: number,
  client: ImportedClient,
  actorId: number,
) {
  const hasProfileData = [client.gstin, client.pan, client.state, client.city, client.pincode]
    .some((value) => value != null && value.length > 0);
  if (hasProfileData) {
    await connection.execute(
      `INSERT INTO client_profiles (client_id, gstin, pan, state, city, pincode, created_by, updated_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         gstin = IF(gstin = '' AND VALUES(gstin) <> '', VALUES(gstin), gstin),
         pan = IF(pan = '' AND VALUES(pan) <> '', VALUES(pan), pan),
         state = IF(state = '' AND VALUES(state) <> '', VALUES(state), state),
         city = IF(city = '' AND VALUES(city) <> '', VALUES(city), city),
         pincode = IF(pincode = '' AND VALUES(pincode) <> '', VALUES(pincode), pincode),
         updated_by = VALUES(updated_by)`,
      [clientId, client.gstin ?? '', client.pan ?? '', client.state ?? '', client.city ?? '', client.pincode ?? '', actorId, actorId],
    );
  }
  const hasComplianceData =
    client.gstRegistrationType !== undefined ||
    client.accountingEnabled !== undefined ||
    client.gstEnabled !== undefined ||
    client.services !== undefined;
  if (hasComplianceData) {
    await connection.execute(
      `INSERT INTO client_compliance (client_id, gst_registration_type, accounting_enabled, gst_enabled, services_json, service_periods_json, created_by, updated_by)
       VALUES (?, ?, ?, ?, ?, JSON_ARRAY(), ?, ?)
       ON DUPLICATE KEY UPDATE client_id = client_id`,
      [
        clientId,
        client.gstRegistrationType ?? 'unregistered',
        client.accountingEnabled ?? true,
        client.gstEnabled ?? false,
        JSON.stringify(client.services ?? []),
        actorId,
        actorId,
      ],
    );
  }
}

async function recordImportReconciliation(
  connection: Awaited<ReturnType<typeof pool.getConnection>>,
  client: ImportedClient,
  targetId: number | null,
  status: 'applied' | 'conflict',
  conflictReason: string,
) {
  const sourcePayload = JSON.stringify(client);
  const payloadHash = createHash('sha256').update(sourcePayload).digest('hex');
  await connection.execute(
    `INSERT INTO data_migration_reconciliation (
       source_system, source_record_id, target_table, target_record_id, payload_hash,
       status, source_payload_json, conflict_reason
     ) VALUES (?, ?, 'users', ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       target_record_id = VALUES(target_record_id), status = VALUES(status),
       source_payload_json = VALUES(source_payload_json), conflict_reason = VALUES(conflict_reason)`,
    [
      'admin_client_import',
      client.sourceRecordId,
      targetId == null ? null : String(targetId),
      payloadHash,
      status,
      sourcePayload,
      conflictReason,
    ],
  );
}

async function recordSuccessfulLogin(user: RowDataPacket): Promise<RowDataPacket> {
  const clientStatus =
    user.role === 'client' && user.client_status === 'onboarded'
      ? 'active'
      : user.client_status;
  const loginStatus = user.role === 'client'
    ? (user.must_change_password ? 'active' : 'passwordChanged')
    : user.login_status;
  const lastLoginAt = new Date();
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    await connection.execute<ResultSetHeader>(
      `UPDATE users
       SET last_login_at = ?,
           client_status = CASE
             WHEN role = 'client' AND client_status = 'onboarded' THEN 'active'
             ELSE client_status
           END,
           login_status = CASE WHEN role = 'client' THEN ? ELSE login_status END,
           identity_revision = CASE
             WHEN role = 'client' THEN identity_revision + 1
             ELSE identity_revision
           END
       WHERE id = ?`,
      [lastLoginAt, loginStatus, user.id],
    );
    if (user.role === 'client') {
      await recordClientDataChange(connection, user.id, user.id, 'identity.login', {
        clientStatus,
        loginStatus,
      });
    }
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
  return {
    ...user,
    client_status: clientStatus,
    login_status: loginStatus,
    identity_revision: user.role === 'client'
      ? Number(user.identity_revision ?? 1) + 1
      : user.identity_revision,
    last_login_at: lastLoginAt,
  };
}