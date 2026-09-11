import { randomUUID } from 'node:crypto';

import sql from 'mssql';

import { AuthRepository, AuthUserRecord } from '../services/authService.js';
import { EmailOtpRepository } from '../services/emailOtpService.js';
import { UserRole } from '../types/securityContext.js';
import { getSqlPool } from './sqlServer.js';

export class SqlAuthRepository implements AuthRepository, EmailOtpRepository {
  async findUserByIdentifier(identifier: string) {
    const pool = await getSqlPool();
    const result = await pool.request()
      .input('identifier', sql.NVarChar(320), identifier)
      .query(`
        SELECT TOP 1 *
        FROM USERS
        WHERE email = LOWER(@identifier) OR mobile = @identifier
      `);
    return result.recordset[0] ? mapUser(result.recordset[0]) : null;
  }

  async findUserById(userId: string) {
    const pool = await getSqlPool();
    const result = await pool.request()
      .input('userId', sql.NVarChar(100), userId)
      .query('SELECT TOP 1 * FROM USERS WHERE user_id = @userId');
    return result.recordset[0] ? mapUser(result.recordset[0]) : null;
  }

  async recordSuccessfulLogin(userId: string) {
    const pool = await getSqlPool();
    await pool.request()
      .input('userId', sql.NVarChar(100), userId)
      .query(`
        UPDATE USERS
        SET last_login_at = SYSUTCDATETIME(), updated_at = SYSUTCDATETIME()
        WHERE user_id = @userId
      `);
  }

  async markEmailVerified(userId: string) {
    const pool = await getSqlPool();
    await pool.request()
      .input('userId', sql.NVarChar(100), userId)
      .query(`
        UPDATE USERS
        SET email_verified_at = COALESCE(email_verified_at, SYSUTCDATETIME()), updated_at = SYSUTCDATETIME()
        WHERE user_id = @userId
      `);
  }

  async updatePassword(userId: string, passwordHash: string) {
    const pool = await getSqlPool();
    await pool.request()
      .input('userId', sql.NVarChar(100), userId)
      .input('passwordHash', sql.NVarChar(500), passwordHash)
      .query(`
        UPDATE USERS
        SET password_hash = @passwordHash, must_change_password = 0, updated_at = SYSUTCDATETIME()
        WHERE user_id = @userId
      `);
  }

  async replaceOtp(input: {
    userId: string;
    purpose: string;
    codeHash: string;
    expiresAt: Date;
  }) {
    const pool = await getSqlPool();
    await pool.request()
      .input('otpId', sql.NVarChar(100), randomUUID())
      .input('userId', sql.NVarChar(100), input.userId)
      .input('purpose', sql.NVarChar(40), input.purpose)
      .input('codeHash', sql.Char(64), input.codeHash)
      .input('expiresAt', sql.DateTime2, input.expiresAt)
      .query(`
        DELETE FROM AUTH_OTP_CODES
        WHERE user_id = @userId AND purpose = @purpose;
        INSERT INTO AUTH_OTP_CODES (otp_id, user_id, purpose, code_hash, expires_at, attempts_remaining, created_at)
        VALUES (@otpId, @userId, @purpose, @codeHash, @expiresAt, 5, SYSUTCDATETIME());
      `);
  }

  async consumeOtp(input: { userId: string; purpose: string; codeHash: string }) {
    const pool = await getSqlPool();
    const result = await pool.request()
      .input('userId', sql.NVarChar(100), input.userId)
      .input('purpose', sql.NVarChar(40), input.purpose)
      .input('codeHash', sql.Char(64), input.codeHash)
      .query(`
        DELETE FROM AUTH_OTP_CODES
        OUTPUT DELETED.otp_id
        WHERE user_id = @userId AND purpose = @purpose AND code_hash = @codeHash
          AND expires_at > SYSUTCDATETIME() AND attempts_remaining > 0;
        UPDATE AUTH_OTP_CODES
        SET attempts_remaining = attempts_remaining - 1
        WHERE user_id = @userId AND purpose = @purpose AND expires_at > SYSUTCDATETIME()
          AND attempts_remaining > 0;
      `);
    return result.recordset.length > 0;
  }

  async saveRefreshToken(input: {
    tokenHash: string;
    userId: string;
    expiresAt: Date;
  }) {
    const pool = await getSqlPool();
    await pool.request()
      .input('tokenId', sql.NVarChar(100), randomUUID())
      .input('tokenHash', sql.Char(64), input.tokenHash)
      .input('userId', sql.NVarChar(100), input.userId)
      .input('expiresAt', sql.DateTime2, input.expiresAt)
      .query(`
        DELETE FROM REFRESH_TOKENS WHERE expires_at <= SYSUTCDATETIME();
        INSERT INTO REFRESH_TOKENS (token_id, token_hash, user_id, expires_at, created_at)
        VALUES (@tokenId, @tokenHash, @userId, @expiresAt, SYSUTCDATETIME());
      `);
  }

  async consumeRefreshToken(tokenHash: string) {
    const pool = await getSqlPool();
    const result = await pool.request()
      .input('tokenHash', sql.Char(64), tokenHash)
      .query(`
        DELETE FROM REFRESH_TOKENS
        OUTPUT DELETED.user_id
        WHERE token_hash = @tokenHash AND expires_at > SYSUTCDATETIME()
      `);
    return result.recordset[0]?.user_id?.toString() ?? null;
  }

  async createBootstrapAdmin(input: {
    name: string;
    email: string;
    mobile: string;
    firmName: string;
    passwordHash: string;
  }) {
    const pool = await getSqlPool();
    const existing = await this.findUserByIdentifier(input.email.toLowerCase());
    if (existing) return { user: existing, created: false };

    const userId = randomUUID();
    const tenantId = randomUUID();
    const companyId = randomUUID();
    const branchId = randomUUID();
    await pool.request()
      .input('userId', sql.NVarChar(100), userId)
      .input('name', sql.NVarChar(200), input.name)
      .input('email', sql.NVarChar(320), input.email.toLowerCase())
      .input('mobile', sql.NVarChar(20), input.mobile)
      .input('tenantId', sql.NVarChar(100), tenantId)
      .input('companyId', sql.NVarChar(100), companyId)
      .input('branchId', sql.NVarChar(100), branchId)
      .input('firmName', sql.NVarChar(200), input.firmName)
      .input('passwordHash', sql.NVarChar(500), input.passwordHash)
      .query(`
        INSERT INTO USERS (
          user_id, name, email, mobile, role, tenant_id, company_id, branch_id,
          firm_name, password_hash, is_active, must_change_password, created_at, updated_at
        ) VALUES (
          @userId, @name, @email, @mobile, 'super_admin', @tenantId, @companyId,
          @branchId, @firmName, @passwordHash, 1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()
        )
      `);
    const user = await this.findUserById(userId);
    if (!user) throw new Error('Admin user creation could not be verified.');
    return { user, created: true };
  }
}

function mapUser(row: Record<string, unknown>): AuthUserRecord {
  return {
    id: String(row.user_id),
    name: String(row.name),
    email: String(row.email),
    mobile: String(row.mobile),
    role: String(row.role) as UserRole,
    tenantId: String(row.tenant_id),
    companyId: String(row.company_id),
    branchId: String(row.branch_id),
    firmName: String(row.firm_name),
    passwordHash: String(row.password_hash),
    isActive: Boolean(row.is_active),
    mustChangePassword: Boolean(row.must_change_password),
    createdAt: new Date(String(row.created_at)),
    lastLoginAt: row.last_login_at ? new Date(String(row.last_login_at)) : null,
  };
}