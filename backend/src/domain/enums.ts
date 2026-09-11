export type InputType = 'text' | 'voice' | 'ocr';

export type CommandStatus =
  | 'question'
  | 'draft_ready'
  | 'awaiting_confirmation'
  | 'success'
  | 'failed'
  | 'cancelled'
  | 'processing'
  | 'ambiguous'
  | 'needs_input';

export type CommandIntent =
  | 'UNKNOWN'
  | 'OPEN_SALES'
  | 'OPEN_PURCHASE'
  | 'OPEN_REPORTS'
  | 'SHOW_SALES'
  | 'CREATE_SALES_INVOICE'
  | 'PRINT'
  | 'CONFIRM'
  | 'CANCEL';

export type ConversationState =
  | 'ACTIVE'
  | 'WAITING_FOR_CONFIRMATION'
  | 'COMPLETED'
  | 'CANCELLED';

export type RiskLevel = 'LOW' | 'MEDIUM' | 'HIGH' | 'VERY_HIGH';
