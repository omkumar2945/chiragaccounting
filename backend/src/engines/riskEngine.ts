import { CommandIntent, RiskLevel } from '../domain/enums.js';

export class RiskEngine {
  levelFor(intent: CommandIntent): RiskLevel {
    switch (intent) {
      case 'CREATE_SALES_INVOICE':
        return 'MEDIUM';
      case 'PRINT':
        return 'LOW';
      case 'CONFIRM':
        return 'HIGH';
      default:
        return 'LOW';
    }
  }

  needsConfirmation(intent: CommandIntent): boolean {
    return intent === 'CONFIRM';
  }
}
