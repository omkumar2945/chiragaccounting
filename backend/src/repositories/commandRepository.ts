import { randomUUID } from 'node:crypto';

import sql from 'mssql';

import { CommandRecord, ConversationSnapshot } from '../domain/models.js';
import { getSqlPool } from './sqlServer.js';
import { SecurityContext } from '../types/securityContext.js';

export class CommandRepository {
  async findByIdempotencyKey(key: string, ctx: SecurityContext): Promise<CommandRecord | null> {
    const pool = await getSqlPool();
    const result = await pool
      .request()
      .input('idempotencyKey', sql.NVarChar(180), key)
      .input('tenantId', sql.NVarChar(100), ctx.tenantId)
      .query(`
        SELECT TOP 1 *
        FROM COMMANDS
        WHERE idempotency_key = @idempotencyKey
          AND tenant_id = @tenantId
        ORDER BY created_at DESC
      `);

    const row = result.recordset[0];
    return row ? this.mapCommand(row) : null;
  }

  async createCommand(record: Omit<CommandRecord, 'commandId'>, ctx: SecurityContext): Promise<CommandRecord> {
    const commandId = randomUUID();
    const pool = await getSqlPool();
    await pool
      .request()
      .input('commandId', sql.NVarChar(100), commandId)
      .input('idempotencyKey', sql.NVarChar(180), record.idempotencyKey)
      .input('tenantId', sql.NVarChar(100), ctx.tenantId)
      .input('companyId', sql.NVarChar(100), ctx.companyId)
      .input('branchId', sql.NVarChar(100), ctx.branchId)
      .input('financialYear', sql.NVarChar(25), ctx.financialYear)
      .input('userId', sql.NVarChar(100), ctx.userId)
      .input('conversationId', sql.NVarChar(100), record.conversationId)
      .input('inputType', sql.NVarChar(20), record.inputType)
      .input('transcript', sql.NVarChar(sql.MAX), record.transcript)
      .input('intent', sql.NVarChar(100), record.intent)
      .input('status', sql.NVarChar(40), record.status)
      .input('requiresConfirmation', sql.Bit, record.requiresConfirmation ? 1 : 0)
      .input('riskLevel', sql.NVarChar(20), record.riskLevel)
      .input('resultJson', sql.NVarChar(sql.MAX), JSON.stringify(record.resultJson))
      .query(`
        INSERT INTO COMMANDS (
          command_id, idempotency_key, tenant_id, company_id, branch_id, financial_year, user_id,
          conversation_id, input_type, transcript, intent, status, requires_confirmation, risk_level,
          result_json, created_at, updated_at
        ) VALUES (
          @commandId, @idempotencyKey, @tenantId, @companyId, @branchId, @financialYear, @userId,
          @conversationId, @inputType, @transcript, @intent, @status, @requiresConfirmation, @riskLevel,
          @resultJson, SYSUTCDATETIME(), SYSUTCDATETIME()
        )
      `);

    return {
      ...record,
      commandId,
    };
  }

  async updateStatus(commandId: string, status: string, resultJson: Record<string, unknown>) {
    const pool = await getSqlPool();
    await pool
      .request()
      .input('commandId', sql.NVarChar(100), commandId)
      .input('status', sql.NVarChar(40), status)
      .input('resultJson', sql.NVarChar(sql.MAX), JSON.stringify(resultJson))
      .query(`
        UPDATE COMMANDS
        SET status = @status,
            result_json = @resultJson,
            updated_at = SYSUTCDATETIME(),
            completed_at = CASE WHEN @status IN ('success', 'failed', 'cancelled') THEN SYSUTCDATETIME() ELSE completed_at END
        WHERE command_id = @commandId
      `);
  }

  async getStatus(commandId: string, ctx: SecurityContext): Promise<CommandRecord | null> {
    const pool = await getSqlPool();
    const result = await pool
      .request()
      .input('commandId', sql.NVarChar(100), commandId)
      .input('tenantId', sql.NVarChar(100), ctx.tenantId)
      .query(`
        SELECT TOP 1 *
        FROM COMMANDS
        WHERE command_id = @commandId
          AND tenant_id = @tenantId
      `);

    const row = result.recordset[0];
    return row ? this.mapCommand(row) : null;
  }

  private mapCommand(row: any): CommandRecord {
    return {
      commandId: String(row.command_id),
      conversationId: String(row.conversation_id),
      transcript: String(row.transcript ?? ''),
      intent: row.intent,
      status: row.status,
      inputType: row.input_type,
      requiresConfirmation: Boolean(row.requires_confirmation),
      riskLevel: row.risk_level,
      idempotencyKey: row.idempotency_key,
      resultJson: safeJson(row.result_json),
    };
  }
}

export class ConversationRepository {
  async getById(conversationId: string, ctx: SecurityContext): Promise<ConversationSnapshot | null> {
    const pool = await getSqlPool();
    const result = await pool
      .request()
      .input('conversationId', sql.NVarChar(100), conversationId)
      .input('tenantId', sql.NVarChar(100), ctx.tenantId)
      .query(`
        SELECT TOP 1 *
        FROM CONVERSATIONS
        WHERE conversation_id = @conversationId
          AND tenant_id = @tenantId
      `);

    const row = result.recordset[0];
    if (!row) return null;
    return {
      conversationId: String(row.conversation_id),
      status: row.status,
      currentIntent: row.current_intent,
      pendingField: row.pending_field,
      pendingQuestion: row.pending_question,
      context: safeJson(row.context_json),
    };
  }

  async upsert(snapshot: ConversationSnapshot, ctx: SecurityContext) {
    const pool = await getSqlPool();
    await pool
      .request()
      .input('conversationId', sql.NVarChar(100), snapshot.conversationId)
      .input('tenantId', sql.NVarChar(100), ctx.tenantId)
      .input('companyId', sql.NVarChar(100), ctx.companyId)
      .input('branchId', sql.NVarChar(100), ctx.branchId)
      .input('financialYear', sql.NVarChar(25), ctx.financialYear)
      .input('userId', sql.NVarChar(100), ctx.userId)
      .input('status', sql.NVarChar(40), snapshot.status)
      .input('currentIntent', sql.NVarChar(100), snapshot.currentIntent)
      .input('pendingField', sql.NVarChar(100), snapshot.pendingField)
      .input('pendingQuestion', sql.NVarChar(300), snapshot.pendingQuestion)
      .input('contextJson', sql.NVarChar(sql.MAX), JSON.stringify(snapshot.context))
      .query(`
        MERGE CONVERSATIONS AS target
        USING (SELECT @conversationId AS conversation_id) AS source
        ON target.conversation_id = source.conversation_id AND target.tenant_id = @tenantId
        WHEN MATCHED THEN
          UPDATE SET
            status = @status,
            current_intent = @currentIntent,
            pending_field = @pendingField,
            pending_question = @pendingQuestion,
            context_json = @contextJson,
            updated_at = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN
          INSERT (
            conversation_id, tenant_id, company_id, branch_id, financial_year, user_id,
            status, current_intent, pending_field, pending_question, context_json, created_at, updated_at
          )
          VALUES (
            @conversationId, @tenantId, @companyId, @branchId, @financialYear, @userId,
            @status, @currentIntent, @pendingField, @pendingQuestion, @contextJson, SYSUTCDATETIME(), SYSUTCDATETIME()
          );
      `);
  }

  async addMessage(
    conversationId: string,
    sender: 'user' | 'chirag',
    messageType: string,
    text: string,
    metadata: Record<string, unknown> = {},
  ) {
    const pool = await getSqlPool();
    await pool
      .request()
      .input('messageId', sql.NVarChar(100), randomUUID())
      .input('conversationId', sql.NVarChar(100), conversationId)
      .input('sender', sql.NVarChar(20), sender)
      .input('messageType', sql.NVarChar(40), messageType)
      .input('text', sql.NVarChar(sql.MAX), text)
      .input('metadataJson', sql.NVarChar(sql.MAX), JSON.stringify(metadata))
      .query(`
        INSERT INTO CONVERSATION_MESSAGES (
          message_id, conversation_id, sender, message_type, [text], metadata_json, created_at
        ) VALUES (
          @messageId, @conversationId, @sender, @messageType, @text, @metadataJson, SYSUTCDATETIME()
        )
      `);
  }
}

export class AuditRepository {
  async record(params: {
    tenantId: string;
    companyId: string;
    userId: string;
    commandId: string;
    action: string;
    entityType: string;
    entityId: string;
    result: string;
    beforeJson?: Record<string, unknown>;
    afterJson?: Record<string, unknown>;
  }) {
    const pool = await getSqlPool();
    await pool
      .request()
      .input('auditId', sql.NVarChar(100), randomUUID())
      .input('tenantId', sql.NVarChar(100), params.tenantId)
      .input('companyId', sql.NVarChar(100), params.companyId)
      .input('userId', sql.NVarChar(100), params.userId)
      .input('commandId', sql.NVarChar(100), params.commandId)
      .input('action', sql.NVarChar(120), params.action)
      .input('entityType', sql.NVarChar(100), params.entityType)
      .input('entityId', sql.NVarChar(100), params.entityId)
      .input('beforeJson', sql.NVarChar(sql.MAX), JSON.stringify(params.beforeJson ?? {}))
      .input('afterJson', sql.NVarChar(sql.MAX), JSON.stringify(params.afterJson ?? {}))
      .input('result', sql.NVarChar(40), params.result)
      .query(`
        INSERT INTO AUDIT_LOG (
          audit_id, tenant_id, company_id, user_id, command_id, action,
          entity_type, entity_id, before_json, after_json, result, created_at
        ) VALUES (
          @auditId, @tenantId, @companyId, @userId, @commandId, @action,
          @entityType, @entityId, @beforeJson, @afterJson, @result, SYSUTCDATETIME()
        )
      `);
  }
}

function safeJson(value: unknown): Record<string, unknown> {
  if (typeof value !== 'string' || value.trim() === '') return {};
  try {
    const parsed = JSON.parse(value) as Record<string, unknown>;
    return parsed;
  } catch {
    return {};
  }
}
