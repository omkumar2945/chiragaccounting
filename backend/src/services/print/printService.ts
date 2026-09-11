import { env } from '../../config/env.js';
import { SecurityContext } from '../../types/securityContext.js';

export class PrintService {
  async printVoucher(voucherId: string, context: SecurityContext) {
    if (!env.PRINTER_API_URL || !env.PRINTER_API_KEY) {
      throw new Error('CONFIGURATION_REQUIRED:PRINTER_API_URL,PRINTER_API_KEY');
    }

    const response = await fetch(`${env.PRINTER_API_URL}/print/voucher`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${env.PRINTER_API_KEY}`,
      },
      body: JSON.stringify({ voucherId, context }),
    });

    if (!response.ok) {
      throw new Error('PRINT_FAILED');
    }
  }
}
