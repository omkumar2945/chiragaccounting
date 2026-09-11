import { CommandIntent, CommandStatus, ConversationState, InputType, RiskLevel } from './enums.js';

export interface CommandRequestPayload {
  input_type: InputType;
  transcript: string;
  conversation_id?: string | null;
  session_id?: string | null;
  idempotency_key?: string | null;
  client_context?: {
    screen?: string | null;
    voucher_id?: string | null;
    module?: string | null;
  };
}

export interface CommandResponsePayload {
  status: CommandStatus;
  command_id: string;
  conversation_id: string;
  intent: CommandIntent;
  requires_confirmation: boolean;
  message: string;
  pending_field?: string;
  data?: Record<string, unknown>;
  error_code?: string;
}

export interface ConversationSnapshot {
  conversationId: string;
  status: ConversationState;
  currentIntent: CommandIntent;
  pendingField: string | null;
  pendingQuestion: string | null;
  context: Record<string, unknown>;
}

export interface CommandRecord {
  commandId: string;
  conversationId: string;
  transcript: string;
  intent: CommandIntent;
  status: CommandStatus;
  inputType: InputType;
  requiresConfirmation: boolean;
  riskLevel: RiskLevel;
  idempotencyKey: string | null;
  resultJson: Record<string, unknown>;
}
