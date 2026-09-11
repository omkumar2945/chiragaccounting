import { CommandIntent } from '../domain/enums.js';
import { SecurityContext } from '../types/securityContext.js';

export class PermissionEngine {
  canExecute(intent: CommandIntent, context: SecurityContext): { allowed: boolean; reason?: string } {
    if (intent === 'UNKNOWN') {
      return { allowed: true };
    }

    if (intent === 'CONFIRM' && !context.permissions.includes('voucher:post')) {
      return { allowed: false, reason: 'You do not have posting permission.' };
    }

    if (intent === 'PRINT' && !context.permissions.includes('print:invoice')) {
      return { allowed: false, reason: 'You do not have print permission.' };
    }

    return { allowed: true };
  }
}
