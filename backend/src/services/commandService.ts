import { randomUUID } from 'node:crypto';

import { CommandResponsePayload, ConversationSnapshot } from '../domain/models.js';
import { CommandIntent } from '../domain/enums.js';
import { SecurityContext } from '../types/securityContext.js';
import { CommandRepository, ConversationRepository, AuditRepository } from '../repositories/commandRepository.js';
import { IntentEngine } from '../engines/intentEngine.js';
import { EntityEngine } from '../engines/entityEngine.js';
import { ConversationEngine } from '../engines/conversationEngine.js';
import { PermissionEngine } from '../engines/permissionEngine.js';
import { ValidationEngine } from '../engines/validationEngine.js';
import { RiskEngine } from '../engines/riskEngine.js';
import { HttpAccountingGateway } from './accounting/httpAccountingGateway.js';
import { PrintService } from './print/printService.js';

interface ExecuteInput {
  inputType: 'text' | 'voice' | 'ocr';
  transcript: string;
  conversationId?: string | null;
  sessionId?: string | null;
  idempotencyKey?: string | null;
}

export class CommandService {
  constructor(
    private readonly commands = new CommandRepository(),
    private readonly conversations = new ConversationRepository(),
    private readonly audits = new AuditRepository(),
    private readonly intentEngine = new IntentEngine(),
    private readonly entityEngine = new EntityEngine(),
    private readonly conversationEngine = new ConversationEngine(),
    private readonly permissionEngine = new PermissionEngine(),
    private readonly validationEngine = new ValidationEngine(),
    private readonly riskEngine = new RiskEngine(),
    private readonly accounting = new HttpAccountingGateway(),
    private readonly printService = new PrintService(),
  ) {}

  async execute(input: ExecuteInput, context: SecurityContext): Promise<CommandResponsePayload> {
    const transcript = input.transcript.trim();
    if (!transcript) {
      return {
        status: 'failed',
        command_id: '',
        conversation_id: input.conversationId ?? input.sessionId ?? randomUUID(),
        intent: 'UNKNOWN',
        requires_confirmation: false,
        message: 'Transcript is required.',
        error_code: 'VALIDATION_FAILED',
      };
    }

    if (input.idempotencyKey) {
      const existing = await this.commands.findByIdempotencyKey(input.idempotencyKey, context);
      if (existing) {
        return {
          status: existing.status,
          command_id: existing.commandId,
          conversation_id: existing.conversationId,
          intent: existing.intent,
          requires_confirmation: existing.requiresConfirmation,
          message: String(existing.resultJson.message ?? 'Request already processed.'),
          data: existing.resultJson,
        };
      }
    }

    const conversationId = input.conversationId ?? input.sessionId ?? randomUUID();
    let snapshot = await this.conversations.getById(conversationId, context);

    const inferredIntent = this.intentEngine.detect(transcript);
    const activeIntent = this.resolveIntentForConversation(snapshot, inferredIntent);

    const permission = this.permissionEngine.canExecute(activeIntent, context);
    if (!permission.allowed) {
      return {
        status: 'failed',
        command_id: '',
        conversation_id: conversationId,
        intent: activeIntent,
        requires_confirmation: false,
        message: permission.reason ?? 'Permission denied.',
        error_code: 'PERMISSION_DENIED',
      };
    }

    if (!snapshot) {
      snapshot = this.conversationEngine.start(conversationId, activeIntent);
    }

    await this.conversations.addMessage(conversationId, 'user', input.inputType === 'voice' ? 'USER_VOICE' : 'USER_TEXT', transcript);

    if (activeIntent === 'OPEN_SALES') {
      return this.finishSimple(snapshot, context, 'NAVIGATION', 'Haan, Sales open kar raha hoon.', {
        action: 'navigate',
        screen: 'sales',
      }, input);
    }

    if (activeIntent === 'SHOW_SALES') {
      return this.finishSimple(snapshot, context, 'SUCCESS', 'Bilkul, aaj ki sales report dikha raha hoon.', {
        action: 'show_report',
        report: 'today_sales',
      }, input);
    }

    if (activeIntent === 'PRINT') {
      const voucherId = String(snapshot.context.voucherId ?? '');
      if (!voucherId) {
        return this.finishSimple(snapshot, context, 'NEEDS_INPUT', 'Print ke liye voucher select kijiye.', {
          pending_field: 'voucher_id',
        }, input);
      }
      await this.printService.printVoucher(voucherId, context);
      return this.finishSimple(snapshot, context, 'SUCCESS', 'Bilkul, invoice print kar raha hoon.', {
        action: 'print',
      }, input);
    }

    if (activeIntent === 'CANCEL' && snapshot.status === 'WAITING_FOR_CONFIRMATION') {
      snapshot = { ...snapshot, status: 'CANCELLED' };
      await this.conversations.upsert(snapshot, context);
      return this.finishSimple(snapshot, context, 'SUCCESS', 'Thik hai. Invoice post nahi kiya.', {
        action: 'cancelled',
      }, input);
    }

    if (snapshot.status === 'WAITING_FOR_CONFIRMATION') {
      if (activeIntent === 'CONFIRM') {
        const validation = this.validationEngine.validateSalesDraft(snapshot.context);
        if (!validation.ok) {
          return this.finishSimple(snapshot, context, 'FAILED', 'message' in validation ? validation.message : 'Invalid sales draft.', {
            action: 'validation_failed',
          }, input);
        }

        const result = await this.accounting.postSalesInvoice(
          {
            customer: String(snapshot.context.customer),
            item: String(snapshot.context.item),
            quantity: Number(snapshot.context.quantity),
            unit: String(snapshot.context.unit),
            rate: Number(snapshot.context.rate),
            deliveryLocation: String(snapshot.context.deliveryLocation),
            transporter: String(snapshot.context.transporter),
            vehicleNumber: String(snapshot.context.vehicleNumber),
            total: Number(snapshot.context.total),
          },
          context,
        );

        const updated = {
          ...snapshot,
          status: 'COMPLETED' as const,
          context: { ...snapshot.context, voucherId: result.voucherId },
        };
        await this.conversations.upsert(updated, context);
        await this.audits.record({
          tenantId: context.tenantId,
          companyId: context.companyId,
          userId: context.userId,
          commandId: '',
          action: 'POST_SALES_INVOICE',
          entityType: 'voucher',
          entityId: result.voucherId,
          result: 'success',
          beforeJson: snapshot.context,
          afterJson: updated.context,
        });

        return this.finishSimple(updated, context, 'SUCCESS', 'Invoice successfully post ho gaya.', {
          action: 'posted',
          voucher_id: result.voucherId,
        }, input);
      }

      return this.finishSimple(snapshot, context, 'AWAITING_CONFIRMATION', 'Invoice ready hai. Post kar doon?', {
        pending_field: 'confirmation',
      }, input);
    }

    const entities = this.entityEngine.extract(transcript);
    const advanced = this.conversationEngine.advance(snapshot, entities);
    snapshot = advanced.snapshot;
    await this.conversations.upsert(snapshot, context);

    if (advanced.awaitingConfirmation) {
      return this.finishSimple(snapshot, context, 'AWAITING_CONFIRMATION', advanced.draftReadyMessage ?? 'Draft ready hai. Confirm karein?', {
        pending_field: 'confirmation',
        draft: snapshot.context,
      }, input);
    }

    if (advanced.needsInputMessage) {
      return this.finishSimple(snapshot, context, 'NEEDS_INPUT', advanced.needsInputMessage, {
        pending_field: snapshot.pendingField,
      }, input);
    }

    return this.finishSimple(snapshot, context, 'QUESTION', 'Please continue.', {
      pending_field: snapshot.pendingField,
    }, input);
  }

  async confirm(commandId: string, conversationId: string, context: SecurityContext): Promise<CommandResponsePayload> {
    const transcript = 'confirm';
    return this.execute(
      {
        inputType: 'text',
        transcript,
        conversationId,
        sessionId: conversationId,
        idempotencyKey: `confirm-${commandId}`,
      },
      context,
    );
  }

  async cancel(commandId: string, conversationId: string, context: SecurityContext): Promise<CommandResponsePayload> {
    const transcript = 'cancel';
    return this.execute(
      {
        inputType: 'text',
        transcript,
        conversationId,
        sessionId: conversationId,
        idempotencyKey: `cancel-${commandId}`,
      },
      context,
    );
  }

  async status(commandId: string, context: SecurityContext): Promise<CommandResponsePayload> {
    const record = await this.commands.getStatus(commandId, context);
    if (!record) {
      return {
        status: 'failed',
        command_id: commandId,
        conversation_id: '',
        intent: 'UNKNOWN',
        requires_confirmation: false,
        message: 'Command not found.',
        error_code: 'NOT_FOUND',
      };
    }

    return {
      status: record.status,
      command_id: record.commandId,
      conversation_id: record.conversationId,
      intent: record.intent,
      requires_confirmation: record.requiresConfirmation,
      message: String(record.resultJson.message ?? 'Status fetched.'),
      data: record.resultJson,
    };
  }

  private resolveIntentForConversation(snapshot: ConversationSnapshot | null, inferredIntent: CommandIntent): CommandIntent {
    if (!snapshot) return inferredIntent;

    if (snapshot.currentIntent === 'CREATE_SALES_INVOICE') {
      if (inferredIntent === 'CONFIRM' || inferredIntent === 'CANCEL') {
        return inferredIntent;
      }
      return 'CREATE_SALES_INVOICE';
    }

    return inferredIntent;
  }

  private async finishSimple(
    snapshot: ConversationSnapshot,
    context: SecurityContext,
    statusLabel: 'QUESTION' | 'DRAFT_READY' | 'AWAITING_CONFIRMATION' | 'SUCCESS' | 'FAILED' | 'NEEDS_INPUT' | 'NAVIGATION',
    message: string,
    data: Record<string, unknown>,
    input: ExecuteInput,
  ): Promise<CommandResponsePayload> {
    const statusMap = {
      QUESTION: 'question',
      DRAFT_READY: 'draft_ready',
      AWAITING_CONFIRMATION: 'awaiting_confirmation',
      SUCCESS: 'success',
      FAILED: 'failed',
      NEEDS_INPUT: 'needs_input',
      NAVIGATION: 'success',
    } as const;

    const status = statusMap[statusLabel];

    const commandRecord = await this.commands.createCommand(
      {
        conversationId: snapshot.conversationId,
        transcript: input.transcript,
        intent: snapshot.currentIntent,
        status,
        inputType: input.inputType,
        requiresConfirmation: status === 'awaiting_confirmation',
        riskLevel: this.riskEngine.levelFor(snapshot.currentIntent),
        idempotencyKey: input.idempotencyKey ?? null,
        resultJson: { ...data, message },
      },
      context,
    );

    await this.conversations.addMessage(
      snapshot.conversationId,
      'chirag',
      status === 'awaiting_confirmation' ? 'CONFIRMATION' : 'CHIRAG_TEXT',
      message,
      data,
    );

    await this.audits.record({
      tenantId: context.tenantId,
      companyId: context.companyId,
      userId: context.userId,
      commandId: commandRecord.commandId,
      action: snapshot.currentIntent,
      entityType: 'conversation',
      entityId: snapshot.conversationId,
      result: status,
      afterJson: data,
    });

    return {
      status,
      command_id: commandRecord.commandId,
      conversation_id: snapshot.conversationId,
      intent: snapshot.currentIntent,
      requires_confirmation: status === 'awaiting_confirmation',
      message,
      pending_field: typeof data.pending_field === 'string' ? data.pending_field : undefined,
      data,
    };
  }
}
