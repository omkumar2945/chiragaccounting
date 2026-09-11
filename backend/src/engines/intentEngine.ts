import { CommandIntent } from '../domain/enums.js';

export class IntentEngine {
  detect(transcript: string): CommandIntent {
    const t = transcript.trim().toLowerCase();

    if (!t) return 'UNKNOWN';

    if (this.hasAny(t, ['cancel', 'nahi', 'mat karo', 'stop'])) return 'CANCEL';
    if (this.hasAny(t, ['confirm', 'haan', 'yes', 'post karo', 'kar do', 'ok', 'ji'])) return 'CONFIRM';

    if (this.hasAny(t, ['sales kholo', 'open sales', 'sales open'])) return 'OPEN_SALES';
    if (this.hasAny(t, ['purchase kholo', 'open purchase', 'purchase open'])) return 'OPEN_PURCHASE';
    if (this.hasAny(t, ['reports kholo', 'open reports', 'report open'])) return 'OPEN_REPORTS';

    if (this.hasAny(t, ['aaj ka sales', 'today sales', 'sales report'])) return 'SHOW_SALES';
    if (this.hasAny(t, ['print karo', 'print', 'invoice print'])) return 'PRINT';

    if (this.hasAny(t, ['bill banana', 'invoice banao', 'sales invoice create', 'mujhe bill banana'])) {
      return 'CREATE_SALES_INVOICE';
    }

    return 'UNKNOWN';
  }

  private hasAny(value: string, checks: string[]) {
    return checks.some((c) => value.includes(c));
  }
}
