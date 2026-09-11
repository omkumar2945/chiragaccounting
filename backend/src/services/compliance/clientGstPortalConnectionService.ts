import crypto from 'node:crypto';

import sql from 'mssql';

import { env } from '../../config/env.js';
import { getSqlPool } from '../../repositories/sqlServer.js';
import { SecurityContext } from '../../types/securityContext.js';

export type ClientGstPortalConnectionType = 'einvoicing' | 'eway_bill';

export interface ClientGstPortalConnectionInput {
  providerName: string;
  baseUrl: string;
  authType: 'token' | 'api_key' | 'bearer';
  credential: string;
  enabled: boolean;
  applicabilityThreshold?: number;
}

export class ClientGstPortalConnectionService {
  async get(
    context: SecurityContext,
    connectionType: ClientGstPortalConnectionType,
  ) {
    const pool = await getSqlPool();
    const result = await pool
      .request()
      .input('tenantId', sql.NVarChar(100), context.tenantId)
      .input('companyId', sql.NVarChar(100), context.companyId)
      .input('connectionType', sql.NVarChar(30), connectionType)
      .query(`
        SELECT provider_name, base_url, auth_type, is_enabled, applicability_threshold, updated_at
        FROM CLIENT_GST_PORTAL_CONNECTIONS
        WHERE tenant_id = @tenantId
          AND company_id = @companyId
          AND connection_type = @connectionType
      `);
    const row = result.recordset[0] as Record<string, unknown> | undefined;
    return row == null
      ? { configured: false }
      : {
          configured: true,
          enabled: Boolean(row.is_enabled),
          providerName: String(row.provider_name),
          baseUrl: String(row.base_url),
          authType: String(row.auth_type),
          applicabilityThreshold: row.applicability_threshold,
          updatedAt: row.updated_at,
        };
  }

  async save(
    context: SecurityContext,
    connectionType: ClientGstPortalConnectionType,
    input: ClientGstPortalConnectionInput,
  ) {
    const key = this.encryptionKey();
    const providerName = input.providerName.trim();
    const baseUrl = this.normalizeUrl(input.baseUrl);
    const credential = input.credential.trim();
    const applicabilityThreshold = input.applicabilityThreshold;
    if (!providerName || !credential) {
      throw new Error('GST_PORTAL_CONNECTION_INVALID');
    }
    if (applicabilityThreshold != null &&
        (!Number.isFinite(applicabilityThreshold) || applicabilityThreshold < 0)) {
      throw new Error('GST_PORTAL_CONNECTION_INVALID_THRESHOLD');
    }
    const encrypted = this.encrypt(credential, key);
    const pool = await getSqlPool();
    await pool
      .request()
      .input('tenantId', sql.NVarChar(100), context.tenantId)
      .input('companyId', sql.NVarChar(100), context.companyId)
      .input('connectionType', sql.NVarChar(30), connectionType)
      .input('providerName', sql.NVarChar(100), providerName)
      .input('baseUrl', sql.NVarChar(500), baseUrl)
      .input('authType', sql.NVarChar(30), input.authType)
      .input('enabled', sql.Bit, input.enabled)
      .input('applicabilityThreshold', sql.Decimal(18, 2), applicabilityThreshold ?? null)
      .input('ciphertext', sql.NVarChar(sql.MAX), encrypted.ciphertext)
      .input('iv', sql.NVarChar(100), encrypted.iv)
      .input('tag', sql.NVarChar(100), encrypted.tag)
      .input('userId', sql.NVarChar(100), context.userId)
      .query(`
        MERGE CLIENT_GST_PORTAL_CONNECTIONS AS target
        USING (SELECT @tenantId AS tenant_id, @companyId AS company_id,
                      @connectionType AS connection_type) AS source
        ON target.tenant_id = source.tenant_id
          AND target.company_id = source.company_id
          AND target.connection_type = source.connection_type
        WHEN MATCHED THEN UPDATE SET
          provider_name = @providerName, base_url = @baseUrl, auth_type = @authType,
          is_enabled = @enabled, applicability_threshold = @applicabilityThreshold,
          credential_ciphertext = @ciphertext, credential_iv = @iv,
          credential_tag = @tag, created_by = @userId, updated_at = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN INSERT (
          tenant_id, company_id, connection_type, is_enabled, applicability_threshold,
          provider_name, base_url, auth_type,
          credential_ciphertext, credential_iv, credential_tag, created_by, created_at, updated_at
        ) VALUES (
          @tenantId, @companyId, @connectionType, @enabled, @applicabilityThreshold,
          @providerName, @baseUrl, @authType,
          @ciphertext, @iv, @tag, @userId, SYSUTCDATETIME(), SYSUTCDATETIME()
        );
      `);
    return this.get(context, connectionType);
  }

  private encryptionKey() {
    const value = env.PORTAL_CREDENTIAL_ENCRYPTION_KEY;
    if (!value) throw new Error('CONFIGURATION_REQUIRED:PORTAL_CREDENTIAL_ENCRYPTION_KEY');
    return Buffer.from(value, 'hex');
  }

  private normalizeUrl(value: string) {
    try {
      return new URL(value.trim()).toString();
    } catch {
      throw new Error('GST_PORTAL_CONNECTION_INVALID_URL');
    }
  }

  private encrypt(value: string, key: Buffer) {
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
    const ciphertext = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
    return {
      ciphertext: ciphertext.toString('base64'),
      iv: iv.toString('base64'),
      tag: cipher.getAuthTag().toString('base64'),
    };
  }
}