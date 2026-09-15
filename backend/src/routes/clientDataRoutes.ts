import { Router } from 'express';
import type { Response } from 'express';
import bcrypt from 'bcryptjs';
import type { ResultSetHeader, RowDataPacket } from 'mysql2';
import { z } from 'zod';

import pool from '../database.js';
import { AuthRequest, isAdmin as requireAdmin, verifyToken } from '../middleware/auth.js';
import {
  clientDataForRole,
  type AuthoritativeClientData,
} from '../services/clientDataVisibility.js';
import { recordClientDataChange } from '../services/clientDataAudit.js';
import { nextClientDataRevision } from '../services/clientDataConcurrency.js';
import {
  clientProfilePatchSchema,
  profileFieldNames,
  type ClientProfilePatch,
  type ProfileField,
} from '../services/clientProfilePatch.js';
import { normalizeMobile } from '../services/clientImportValidation.js';
import { generateTemporaryPassword } from '../security/temporaryPassword.js';

const clientIdSchema = z.coerce.number().int().positive();
const revisionSchema = z.coerce.number().int().positive().optional();
const adminRoles = new Set(['super_admin', 'admin', 'manager']);
export const clientCredentialActionSchema = z.object({
  action: z.enum(['onboard', 'reset']),
});
export const clientIdentityPatchSchema = z.object({
  email: z.string().trim().email().max(320).transform((value) => value.toLowerCase()).optional(),
  mobile: z.string().trim().transform(normalizeMobile).refine(
    (value) => /^\d{10}$/.test(value),
    'A valid 10-digit mobile number is required.',
  ).optional(),
  clientStatus: z.enum(['draft', 'pendingApproval', 'notOnboarded', 'onboarded', 'active', 'inactive', 'suspended', 'archived']).optional(),
  loginStatus: z.enum(['loginNotCreated', 'credentialsSent', 'neverLoggedIn', 'active', 'passwordChanged', 'locked']).optional(),
  isActive: z.boolean().optional(),
  mustChangePassword: z.boolean().optional(),
  ifMatchVersion: revisionSchema,
}).superRefine((input, context) => {
  if (
    input.email === undefined &&
    input.mobile === undefined &&
    input.clientStatus === undefined &&
    input.loginStatus === undefined &&
    input.isActive === undefined &&
    input.mustChangePassword === undefined
  ) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'At least one client identity field is required.' });
  }
});
type ClientIdentityPatch = z.infer<typeof clientIdentityPatchSchema>;
const complianceSchema = z.object({
  gstRegistrationType: z.enum(['unregistered', 'regular', 'composition']), accountingEnabled: z.boolean(),
  gstEnabled: z.boolean(), services: z.array(z.string().trim().min(1).max(100)).max(50),
  servicePeriods: z.array(z.record(z.unknown())).max(100),
  ifMatchVersion: revisionSchema,
});
const assignmentSchema = z.object({
  accountantUserId: z.coerce.number().int().positive().nullable(), caUserId: z.coerce.number().int().positive().nullable(),
  oldAccountingApproved: z.boolean(), reportsPublished: z.boolean(), auditEnabled: z.boolean(),
  financialStatementsEnabled: z.boolean(), reportSigningEnabled: z.boolean(),
  bankProjectReportsEnabled: z.boolean(), staffDelegationEnabled: z.boolean(),
  ifMatchVersion: revisionSchema,
});
const accessSchema = z.object({
  loginEnabled: z.boolean(), mobileLoginEnabled: z.boolean(), webLoginEnabled: z.boolean(), twoFactorRequired: z.boolean(),
  accountLocked: z.boolean(), subscriptionPlan: z.string().trim().min(1).max(40), billingMode: z.string().trim().min(1).max(60),
  accountingMode: z.string().trim().min(1).max(60), purchaseEntryMode: z.string().trim().min(1).max(30),
  salesEntryMode: z.string().trim().min(1).max(30), modules: z.record(z.unknown()), dashboardWidgets: z.record(z.boolean()),
  documentHubAccess: z.record(z.unknown()),
  ifMatchVersion: revisionSchema,
});
const workspaceSchema = z.object({
  client360Enabled: z.boolean(), documentFolderEnabled: z.boolean(), complianceWorkspaceEnabled: z.boolean(),
  accountingWorkspaceEnabled: z.boolean(), aiWorkspaceEnabled: z.boolean(), notificationSettingsEnabled: z.boolean(),
  ifMatchVersion: revisionSchema,
});

export function clientDataRoutes() {
  const router = Router();
  router.use(verifyToken);

  router.get('/clients', async (req: AuthRequest, res, next) => {
    try {
      res.json({ data: { clients: await loadAccessibleClientData(req) } });
    } catch (error) { next(error); }
  });

  router.get('/clients/:clientId/authoritative', async (req: AuthRequest, res, next) => {
    try {
      const clientId = clientIdSchema.parse(req.params.clientId);
      if (!(await canAccessClient(req, clientId))) return res.status(403).json({ message: 'Client access denied.' });
      await sendClientData(req, res, clientId);
    } catch (error) { next(error); }
  });

  router.patch('/clients/:clientId/profile', async (req: AuthRequest, res, next) => {
    try {
      const clientId = clientIdSchema.parse(req.params.clientId);
      if (!canEditProfile(req, clientId)) return res.status(403).json({ message: 'Profile update access denied.' });
      const input = clientProfilePatchSchema.parse(req.body);
      await requireClient(clientId);
      await updateProfile(clientId, input, req.user!.id);
      await sendClientData(req, res, clientId);
    } catch (error) { next(error); }
  });

  router.patch('/clients/:clientId/identity', async (req: AuthRequest, res, next) => {
    try {
      const clientId = clientIdSchema.parse(req.params.clientId);
      if (!isAdmin(req)) return res.status(403).json({ message: 'Client administration access required.' });
      const input = clientIdentityPatchSchema.parse(req.body);
      await requireClient(clientId);
      await updateClientIdentity(clientId, input, req.user!.id);
      await sendClientData(req, res, clientId);
    } catch (error) { next(error); }
  });

  router.post('/clients/:clientId/credentials', requireAdmin, async (req: AuthRequest, res, next) => {
    try {
      const clientId = clientIdSchema.parse(req.params.clientId);
      if (!isAdmin(req)) return res.status(403).json({ message: 'Client administration access required.' });
      const input = clientCredentialActionSchema.parse(req.body);
      const temporaryPassword = await provisionClientCredentials(
        clientId,
        input.action,
        req.user!.id,
      );
      await sendClientDataWithTemporaryPassword(req, res, clientId, temporaryPassword);
    } catch (error) { next(error); }
  });

  router.patch('/clients/:clientId/compliance', async (req: AuthRequest, res, next) => {
    try {
      const clientId = clientIdSchema.parse(req.params.clientId);
      if (!isAdmin(req)) return res.status(403).json({ message: 'Client administration access required.' });
      const input = complianceSchema.parse(req.body);
      await requireClient(clientId);
      await executeAuditedClientChange('client_compliance', clientId, req.user!.id, 'compliance.updated', input, input.ifMatchVersion, async (connection, revision) => {
        await connection.execute(
          `INSERT INTO client_compliance (client_id, gst_registration_type, accounting_enabled, gst_enabled, services_json, service_periods_json, created_by, updated_by, revision)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE gst_registration_type = VALUES(gst_registration_type), accounting_enabled = VALUES(accounting_enabled), gst_enabled = VALUES(gst_enabled), services_json = VALUES(services_json), service_periods_json = VALUES(service_periods_json), updated_by = VALUES(updated_by), revision = VALUES(revision)`,
          [clientId, input.gstRegistrationType, input.accountingEnabled, input.gstEnabled, JSON.stringify(input.services), JSON.stringify(input.servicePeriods), req.user!.id, req.user!.id, revision],
        );
      });
      await sendClientData(req, res, clientId);
    } catch (error) { next(error); }
  });

  router.patch('/clients/:clientId/assignments', async (req: AuthRequest, res, next) => {
    try {
      const clientId = clientIdSchema.parse(req.params.clientId);
      if (!isAdmin(req)) return res.status(403).json({ message: 'Admin access required.' });
      const input = assignmentSchema.parse(req.body);
      await requireClient(clientId);
      await requireAssignableUsers(input.accountantUserId, input.caUserId);
      await executeAuditedClientChange('client_assignments', clientId, req.user!.id, 'assignment.updated', input, input.ifMatchVersion, async (connection, revision) => {
        await connection.execute(
          `INSERT INTO client_assignments (client_id, accountant_user_id, ca_user_id, assigned_by, old_accounting_approved, reports_published, audit_enabled, financial_statements_enabled, report_signing_enabled, bank_project_reports_enabled, staff_delegation_enabled, revision)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE accountant_user_id = VALUES(accountant_user_id), ca_user_id = VALUES(ca_user_id), assigned_by = VALUES(assigned_by), old_accounting_approved = VALUES(old_accounting_approved), reports_published = VALUES(reports_published), audit_enabled = VALUES(audit_enabled), financial_statements_enabled = VALUES(financial_statements_enabled), report_signing_enabled = VALUES(report_signing_enabled), bank_project_reports_enabled = VALUES(bank_project_reports_enabled), staff_delegation_enabled = VALUES(staff_delegation_enabled), revision = VALUES(revision)`,
          [clientId, input.accountantUserId, input.caUserId, req.user!.id, input.oldAccountingApproved, input.reportsPublished, input.auditEnabled, input.financialStatementsEnabled, input.reportSigningEnabled, input.bankProjectReportsEnabled, input.staffDelegationEnabled, revision],
        );
      });
      await sendClientData(req, res, clientId);
    } catch (error) { next(error); }
  });

  router.patch('/clients/:clientId/access', async (req: AuthRequest, res, next) => {
    try {
      const clientId = clientIdSchema.parse(req.params.clientId);
      if (!isAdmin(req)) return res.status(403).json({ message: 'Admin access required.' });
      const input = accessSchema.parse(req.body);
      await requireClient(clientId);
      await executeAuditedClientChange('client_access_policies', clientId, req.user!.id, 'access.updated', input, input.ifMatchVersion, async (connection, revision) => {
        await connection.execute(
          `INSERT INTO client_access_policies (client_id, login_enabled, mobile_login_enabled, web_login_enabled, two_factor_required, account_locked, subscription_plan, billing_mode, accounting_mode, purchase_entry_mode, sales_entry_mode, modules_json, dashboard_widgets_json, document_hub_access_json, created_by, updated_by, revision)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE login_enabled = VALUES(login_enabled), mobile_login_enabled = VALUES(mobile_login_enabled), web_login_enabled = VALUES(web_login_enabled), two_factor_required = VALUES(two_factor_required), account_locked = VALUES(account_locked), subscription_plan = VALUES(subscription_plan), billing_mode = VALUES(billing_mode), accounting_mode = VALUES(accounting_mode), purchase_entry_mode = VALUES(purchase_entry_mode), sales_entry_mode = VALUES(sales_entry_mode), modules_json = VALUES(modules_json), dashboard_widgets_json = VALUES(dashboard_widgets_json), document_hub_access_json = VALUES(document_hub_access_json), updated_by = VALUES(updated_by), revision = VALUES(revision)`,
          [clientId, input.loginEnabled, input.mobileLoginEnabled, input.webLoginEnabled, input.twoFactorRequired, input.accountLocked, input.subscriptionPlan, input.billingMode, input.accountingMode, input.purchaseEntryMode, input.salesEntryMode, JSON.stringify(input.modules), JSON.stringify(input.dashboardWidgets), JSON.stringify(input.documentHubAccess), req.user!.id, req.user!.id, revision],
        );
      });
      await sendClientData(req, res, clientId);
    } catch (error) { next(error); }
  });

  router.patch('/clients/:clientId/workspace', async (req: AuthRequest, res, next) => {
    try {
      const clientId = clientIdSchema.parse(req.params.clientId);
      if (!isAdmin(req)) return res.status(403).json({ message: 'Client administration access required.' });
      const input = workspaceSchema.parse(req.body);
      await requireClient(clientId);
      await executeAuditedClientChange('client_workspaces', clientId, req.user!.id, 'workspace.updated', input, input.ifMatchVersion, async (connection, revision) => {
        await connection.execute(
          `INSERT INTO client_workspaces (client_id, client_360_enabled, document_folder_enabled, compliance_workspace_enabled, accounting_workspace_enabled, ai_workspace_enabled, notification_settings_enabled, created_by, updated_by, revision)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE client_360_enabled = VALUES(client_360_enabled), document_folder_enabled = VALUES(document_folder_enabled), compliance_workspace_enabled = VALUES(compliance_workspace_enabled), accounting_workspace_enabled = VALUES(accounting_workspace_enabled), ai_workspace_enabled = VALUES(ai_workspace_enabled), notification_settings_enabled = VALUES(notification_settings_enabled), updated_by = VALUES(updated_by), revision = VALUES(revision)`,
          [clientId, input.client360Enabled, input.documentFolderEnabled, input.complianceWorkspaceEnabled, input.accountingWorkspaceEnabled, input.aiWorkspaceEnabled, input.notificationSettingsEnabled, req.user!.id, req.user!.id, revision],
        );
      });
      await sendClientData(req, res, clientId);
    } catch (error) { next(error); }
  });

  return router;
}

async function canAccessClient(req: AuthRequest, clientId: number) {
  if (isAdmin(req) || req.user?.id === clientId) return true;
  const [rows] = await pool.execute<Array<RowDataPacket & { client_id: number }>>(
    'SELECT client_id FROM client_assignments WHERE client_id = ? AND status = \'active\' AND (accountant_user_id = ? OR ca_user_id = ?)',
    [clientId, req.user?.id ?? 0, req.user?.id ?? 0],
  );
  return rows.length > 0;
}

async function sendClientData(req: AuthRequest, res: Response, clientId: number) {
  const data = await loadClientData(clientId);
  if (!data) {
    res.status(404).json({ message: 'Client not found.' });
    return;
  }
  res.json({ data: clientDataForRequester(req, data) });
}

async function sendClientDataWithTemporaryPassword(
  req: AuthRequest,
  res: Response,
  clientId: number,
  temporaryPassword: string,
) {
  const data = await loadClientData(clientId);
  if (!data) {
    res.status(404).json({ message: 'Client not found.' });
    return;
  }
  res.status(201).json({
    data: {
      ...clientDataForRequester(req, data),
      temporaryPassword,
    },
  });
}

function canEditProfile(req: AuthRequest, clientId: number) {
  return isAdmin(req) || req.user?.id === clientId;
}

function isAdmin(req: AuthRequest) { return adminRoles.has(req.user?.role ?? ''); }

async function requireClient(clientId: number) {
  const [rows] = await pool.execute<Array<RowDataPacket & { id: number }>>(
    "SELECT id FROM users WHERE id = ? AND role = 'client' LIMIT 1", [clientId],
  );
  if (!rows[0]) throw new Error('CLIENT_NOT_FOUND');
}

const profileColumns: Record<ProfileField, string> = {
  legalName: 'legal_name', gstin: 'gstin', pan: 'pan', aadhaar: 'aadhaar',
  address: 'address_line', city: 'city', state: 'state', pincode: 'pincode',
  country: 'country', registeredLocation: 'registered_location_json',
  logoFileName: 'logo_file_name', logoDataBase64: 'logo_data_base64',
  invoiceFormat: 'invoice_format', documentMetadata: 'document_metadata_json',
};

async function updateProfile(clientId: number, input: ClientProfilePatch, actorId: number) {
  const clearFields = new Set<ProfileField>(input.clearFields);
  const values: unknown[] = [];
  const assignments: string[] = [];
  for (const field of profileFieldNames) {
    const supplied = input[field] !== undefined || clearFields.has(field);
    if (!supplied) continue;
    const isJson = field === 'registeredLocation' || field === 'documentMetadata';
    const rawValue = clearFields.has(field) ? null : input[field];
    assignments.push(`${profileColumns[field]} = ?`);
    values.push(isJson ? (rawValue == null ? null : JSON.stringify(rawValue)) : rawValue ?? '');
  }

  const userAssignments: string[] = [];
  const userValues: unknown[] = [];
  if (input.name !== undefined) {
    userAssignments.push('name = ?');
    userValues.push(input.name);
  }
  if (input.firmName !== undefined) {
    userAssignments.push('firm_name = ?');
    userValues.push(input.firmName);
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const existingRevision = await clientDataRevision(
      connection,
      'client_profiles',
      clientId,
    );
    const nextRevision = nextClientDataRevision(
      existingRevision,
      input.ifMatchVersion,
    );
    if (existingRevision == null) {
      await connection.execute(
        `INSERT INTO client_profiles (client_id, created_by, updated_by, revision)
         VALUES (?, ?, ?, ?)`,
        [clientId, actorId, actorId, nextRevision],
      );
    }
    if (userAssignments.length > 0) {
      await connection.query({
        sql: `UPDATE users SET ${userAssignments.join(', ')} WHERE id = ? AND role = 'client'`,
        values: [...userValues, clientId],
      });
    }
    if (assignments.length > 0) {
      await connection.query({
        sql: `UPDATE client_profiles SET ${assignments.join(', ')}, updated_by = ?, revision = ? WHERE client_id = ?`,
        values: [...values, actorId, nextRevision, clientId],
      });
    } else {
      await connection.execute(
        'UPDATE client_profiles SET updated_by = ?, revision = ? WHERE client_id = ?',
        [actorId, nextRevision, clientId],
      );
    }
    await recordClientDataChange(connection, clientId, actorId, 'profile.updated', input);
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

async function updateClientIdentity(
  clientId: number,
  input: ClientIdentityPatch,
  actorId: number,
) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [currentRows] = await connection.execute<Array<RowDataPacket & {
      id: number;
      email: string;
      mobile: string;
      identity_revision: number;
    }>>(
      "SELECT id, email, mobile, identity_revision FROM users WHERE id = ? AND role = 'client' FOR UPDATE",
      [clientId],
    );
    const current = currentRows[0];
    if (!current) throw new Error('CLIENT_NOT_FOUND');

    const currentVersion = Number(current.identity_revision);
    if (!Number.isSafeInteger(currentVersion) || currentVersion <= 0) {
      throw new Error('CLIENT_DATA_INVALID_VERSION');
    }
    const nextVersion = nextClientDataRevision(currentVersion, input.ifMatchVersion);
    const nextEmail = input.email ?? current.email;
    const nextMobile = input.mobile ?? current.mobile;
    const [conflicts] = await connection.execute<Array<RowDataPacket & { id: number }>>(
      'SELECT id FROM users WHERE id <> ? AND (email = ? OR mobile = ?) LIMIT 1',
      [clientId, nextEmail, nextMobile],
    );
    if (conflicts.length > 0) throw new Error('CLIENT_IDENTITY_CONFLICT');

    const assignments: string[] = [];
    const values: unknown[] = [];
    const add = (column: string, value: unknown) => {
      if (value === undefined) return;
      assignments.push(`${column} = ?`);
      values.push(value);
    };
    add('email', input.email);
    add('mobile', input.mobile);
    add('client_status', input.clientStatus);
    add('login_status', input.loginStatus);
    add('is_active', input.isActive);
    add('must_change_password', input.mustChangePassword);
    assignments.push('identity_revision = ?', 'updated_at = CURRENT_TIMESTAMP');
    values.push(nextVersion, clientId);
    await connection.query({
      sql: `UPDATE users SET ${assignments.join(', ')} WHERE id = ? AND role = 'client'`,
      values,
    });
    await recordClientDataChange(connection, clientId, actorId, 'identity.updated', input);
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

async function provisionClientCredentials(
  clientId: number,
  action: 'onboard' | 'reset',
  actorId: number,
) {
  const temporaryPassword = generateTemporaryPassword();
  const passwordHash = await bcrypt.hash(temporaryPassword, 12);
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [rows] = await connection.execute<Array<RowDataPacket & {
      client_status: string;
      is_active: number;
      identity_revision: number;
    }>>(
      "SELECT client_status, is_active, identity_revision FROM users WHERE id = ? AND role = 'client' FOR UPDATE",
      [clientId],
    );
    const current = rows[0];
    if (!current) throw new Error('CLIENT_NOT_FOUND');

    const currentVersion = Number(current.identity_revision);
    if (!Number.isSafeInteger(currentVersion) || currentVersion <= 0) {
      throw new Error('CLIENT_DATA_INVALID_VERSION');
    }
    const lifecycle = String(current.client_status);
    if (action === 'onboard' && !['draft', 'pendingApproval', 'notOnboarded'].includes(lifecycle)) {
      throw new Error('CLIENT_ALREADY_ONBOARDED');
    }
    if (action === 'reset' && (!current.is_active || ['draft', 'pendingApproval', 'notOnboarded', 'archived'].includes(lifecycle))) {
      throw new Error('CLIENT_CREDENTIAL_RESET_UNAVAILABLE');
    }

    const nextVersion = nextClientDataRevision(currentVersion, currentVersion);
    if (action === 'onboard') {
      await connection.execute(
        `UPDATE users
         SET password_hash = ?, is_active = TRUE, client_status = 'onboarded',
             login_status = 'neverLoggedIn', must_change_password = TRUE,
             identity_revision = ?, updated_at = CURRENT_TIMESTAMP
         WHERE id = ? AND role = 'client'`,
        [passwordHash, nextVersion, clientId],
      );
    } else {
      await connection.execute(
        `UPDATE users
         SET password_hash = ?, login_status = 'neverLoggedIn',
             must_change_password = TRUE, identity_revision = ?,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = ? AND role = 'client'`,
        [passwordHash, nextVersion, clientId],
      );
    }
    await recordClientDataChange(connection, clientId, actorId, `credentials.${action}`, {
      action,
    });
    await connection.commit();
    return temporaryPassword;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

async function executeAuditedClientChange(
  table: VersionedClientTable,
  clientId: number,
  actorId: number,
  changeType: string,
  payload: unknown,
  expectedVersion: number | undefined,
  change: (
    connection: Awaited<ReturnType<typeof pool.getConnection>>,
    revision: number,
  ) => Promise<void>,
) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const existingRevision = await clientDataRevision(connection, table, clientId);
    await change(connection, nextClientDataRevision(existingRevision, expectedVersion));
    await recordClientDataChange(connection, clientId, actorId, changeType, payload);
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

type VersionedClientTable =
  | 'client_profiles'
  | 'client_compliance'
  | 'client_assignments'
  | 'client_access_policies'
  | 'client_workspaces';

async function clientDataRevision(
  connection: Awaited<ReturnType<typeof pool.getConnection>>,
  table: VersionedClientTable,
  clientId: number,
) {
  const [rows] = await connection.query<Array<RowDataPacket & { revision: number }>>({
    sql: `SELECT revision FROM ${table} WHERE client_id = ? FOR UPDATE`,
    values: [clientId],
  });
  if (!rows[0]) return null;
  const revision = Number(rows[0].revision);
  if (!Number.isSafeInteger(revision) || revision <= 0) {
    throw new Error('CLIENT_DATA_INVALID_VERSION');
  }
  return revision;
}

async function requireAssignableUsers(accountantId: number | null, caId: number | null) {
  const ids = [accountantId, caId].filter((id): id is number => id != null);
  if (ids.length === 0) return;
  const marks = ids.map(() => '?').join(', ');
  const [rows] = await pool.execute<Array<RowDataPacket & { id: number; role: string; is_active: number }>>(
    `SELECT id, role, is_active FROM users WHERE id IN (${marks})`, ids,
  );
  const byId = new Map(rows.map((row) => [row.id, row]));
  const accountant = accountantId == null ? undefined : byId.get(accountantId);
  const ca = caId == null ? undefined : byId.get(caId);
  const accountantRoles = new Set(['accountant', 'manager']);
  const caRoles = new Set(['auditor', 'checker', 'partner', 'firm_admin', 'admin', 'super_admin']);
  if (
    rows.length !== ids.length ||
    (accountant != null && (!accountant.is_active || !accountantRoles.has(accountant.role))) ||
    (ca != null && (!ca.is_active || !caRoles.has(ca.role)))
  ) {
    throw new Error('ASSIGNMENT_USER_INVALID');
  }
}

async function loadAccessibleClientData(req: AuthRequest) {
  const userId = req.user!.id;
  if (isAdmin(req)) {
    const [rows] = await pool.execute<Array<RowDataPacket & { id: number }>>(
      "SELECT id FROM users WHERE role = 'client' ORDER BY created_at DESC",
    );
    const results = await Promise.all(rows.map((row) => loadClientData(row.id)));
    return results
      .filter((client): client is NonNullable<typeof client> => client != null)
      .map((client) => clientDataForRequester(req, client));
  }
  if (req.user!.role === 'client') {
    const client = await loadClientData(userId);
    return client == null ? [] : [clientDataForRequester(req, client)];
  }
  const [rows] = await pool.execute<Array<RowDataPacket & { client_id: number }>>(
    "SELECT client_id FROM client_assignments WHERE status = 'active' AND (accountant_user_id = ? OR ca_user_id = ?) ORDER BY updated_at DESC",
    [userId, userId],
  );
  const results = await Promise.all(rows.map((row) => loadClientData(row.client_id)));
  return results
    .filter((client): client is NonNullable<typeof client> => client != null)
    .map((client) => clientDataForRequester(req, client));
}

async function loadClientData(clientId: number) {
  const [rows] = await pool.execute<Array<RowDataPacket & Record<string, unknown>>>(
    `SELECT u.id, u.name, u.email, u.mobile, u.firm_name, u.role, u.account_origin, u.client_status, u.login_status, u.is_active, u.must_change_password, u.identity_revision, u.created_at, u.last_login_at,
      p.legal_name, p.gstin, p.pan, p.aadhaar, p.address_line, p.city, p.state, p.pincode, p.country, p.registered_location_json, p.logo_file_name, p.logo_data_base64, p.invoice_format, p.document_metadata_json, p.updated_at AS profile_updated_at, p.revision AS profile_revision,
      c.gst_registration_type, c.accounting_enabled, c.gst_enabled, c.services_json, c.service_periods_json, c.revision AS compliance_revision,
      a.accountant_user_id, a.ca_user_id, a.old_accounting_approved, a.reports_published, a.audit_enabled, a.financial_statements_enabled, a.report_signing_enabled, a.bank_project_reports_enabled, a.staff_delegation_enabled, a.revision AS assignment_revision,
      x.login_enabled, x.mobile_login_enabled, x.web_login_enabled, x.two_factor_required, x.account_locked, x.subscription_plan, x.billing_mode, x.accounting_mode, x.purchase_entry_mode, x.sales_entry_mode, x.modules_json, x.dashboard_widgets_json, x.document_hub_access_json, x.revision AS access_revision,
      w.client_360_enabled, w.document_folder_enabled, w.compliance_workspace_enabled, w.accounting_workspace_enabled, w.ai_workspace_enabled, w.notification_settings_enabled, w.revision AS workspace_revision
     FROM users u
     LEFT JOIN client_profiles p ON p.client_id = u.id
     LEFT JOIN client_compliance c ON c.client_id = u.id
     LEFT JOIN client_assignments a ON a.client_id = u.id
     LEFT JOIN client_access_policies x ON x.client_id = u.id
     LEFT JOIN client_workspaces w ON w.client_id = u.id
     WHERE u.id = ? AND u.role = 'client' LIMIT 1`, [clientId],
  );
  return rows[0] == null ? null : mapClientData(rows[0]);
}

function mapClientData(row: RowDataPacket & Record<string, unknown>): AuthoritativeClientData {
  return {
    client: {
      id: String(row.id), name: text(row.name), email: text(row.email), mobile: text(row.mobile),
      firmName: text(row.firm_name), role: text(row.role), accountOrigin: text(row.account_origin),
      clientStatus: text(row.client_status), loginStatus: text(row.login_status), isActive: bool(row.is_active, true),
      mustChangePassword: bool(row.must_change_password, false), version: nullableVersion(row.identity_revision),
      createdAt: isoDate(row.created_at), lastLoginAt: nullableIsoDate(row.last_login_at),
    },
    profile: {
      legalName: text(row.legal_name), gstin: text(row.gstin), pan: text(row.pan), aadhaar: text(row.aadhaar),
      address: text(row.address_line), city: text(row.city), state: text(row.state), pincode: text(row.pincode), country: text(row.country, 'India'),
      registeredLocation: jsonObject(row.registered_location_json), logoFileName: text(row.logo_file_name), logoDataBase64: text(row.logo_data_base64),
      invoiceFormat: text(row.invoice_format, 'Classic'), documentMetadata: jsonObject(row.document_metadata_json), lastUpdatedAt: nullableIsoDate(row.profile_updated_at), version: nullableVersion(row.profile_revision),
    },
    compliance: {
      gstRegistrationType: text(row.gst_registration_type, 'unregistered'), accountingEnabled: bool(row.accounting_enabled, true),
      gstEnabled: bool(row.gst_enabled, false), services: jsonArray(row.services_json), servicePeriods: jsonArray(row.service_periods_json), version: nullableVersion(row.compliance_revision),
    },
    assignment: {
      accountantUserId: nullableId(row.accountant_user_id), caUserId: nullableId(row.ca_user_id), oldAccountingApproved: bool(row.old_accounting_approved, false),
      reportsPublished: bool(row.reports_published, false), auditEnabled: bool(row.audit_enabled, false),
      financialStatementsEnabled: bool(row.financial_statements_enabled, false), reportSigningEnabled: bool(row.report_signing_enabled, false),
      bankProjectReportsEnabled: bool(row.bank_project_reports_enabled, false), staffDelegationEnabled: bool(row.staff_delegation_enabled, false), version: nullableVersion(row.assignment_revision),
    },
    access: {
      loginEnabled: bool(row.login_enabled, true), mobileLoginEnabled: bool(row.mobile_login_enabled, true), webLoginEnabled: bool(row.web_login_enabled, true),
      twoFactorRequired: bool(row.two_factor_required, false), accountLocked: bool(row.account_locked, false), subscriptionPlan: text(row.subscription_plan, 'standard'),
      billingMode: text(row.billing_mode, 'fullBillingSoftware'), accountingMode: text(row.accounting_mode, 'accountsOnly'),
      purchaseEntryMode: text(row.purchase_entry_mode, 'both'), salesEntryMode: text(row.sales_entry_mode, 'both'),
      modules: jsonObject(row.modules_json) ?? {}, dashboardWidgets: jsonObject(row.dashboard_widgets_json) ?? {}, documentHubAccess: jsonObject(row.document_hub_access_json) ?? {}, version: nullableVersion(row.access_revision),
    },
    workspace: {
      client360Enabled: bool(row.client_360_enabled, true), documentFolderEnabled: bool(row.document_folder_enabled, true),
      complianceWorkspaceEnabled: bool(row.compliance_workspace_enabled, true), accountingWorkspaceEnabled: bool(row.accounting_workspace_enabled, true),
      aiWorkspaceEnabled: bool(row.ai_workspace_enabled, true), notificationSettingsEnabled: bool(row.notification_settings_enabled, true), version: nullableVersion(row.workspace_revision),
    },
  };
}

function clientDataForRequester(req: AuthRequest, data: AuthoritativeClientData) {
  return clientDataForRole(req.user?.role ?? '', data);
}

function text(value: unknown, fallback = '') { return typeof value === 'string' && value.trim() ? value.trim() : fallback; }
function nullableId(value: unknown) { return value == null ? null : String(value); }
function nullableVersion(value: unknown) {
  if (value == null) return null;
  const version = Number(value);
  return Number.isSafeInteger(version) && version > 0 ? version : null;
}
function bool(value: unknown, fallback: boolean) { return value == null ? fallback : value === true || value === 1 || value === '1'; }
function isoDate(value: unknown) { return value instanceof Date ? value.toISOString() : new Date(String(value)).toISOString(); }
function nullableIsoDate(value: unknown) { return value == null ? null : isoDate(value); }
function jsonValue(value: unknown): unknown {
  if (typeof value !== 'string') return value;
  try { return JSON.parse(value); } catch { return null; }
}
function jsonArray(value: unknown) { const parsed = jsonValue(value); return Array.isArray(parsed) ? parsed : []; }
function jsonObject(value: unknown) { const parsed = jsonValue(value); return typeof parsed === 'object' && parsed != null && !Array.isArray(parsed) ? parsed as Record<string, unknown> : null; }