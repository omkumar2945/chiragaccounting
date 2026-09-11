import { env } from '../../config/env.js';
import { SecurityContext } from '../../types/securityContext.js';
import { AccountingGateway, DraftSalesInvoice } from './accountingGateway.js';

export class HttpAccountingGateway implements AccountingGateway {
  async postSalesInvoice(input: DraftSalesInvoice, context: SecurityContext): Promise<{ voucherId: string }> {
    if (!env.ACCOUNTING_API_BASE_URL || !env.ACCOUNTING_API_TOKEN) {
      throw new Error('CONFIGURATION_REQUIRED:ACCOUNTING_API_BASE_URL,ACCOUNTING_API_TOKEN');
    }

    const response = await fetch(`${env.ACCOUNTING_API_BASE_URL}/vouchers/sales`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${env.ACCOUNTING_API_TOKEN}`,
        'x-tenant-id': context.tenantId,
        'x-company-id': context.companyId,
        'x-branch-id': context.branchId,
        'x-financial-year': context.financialYear,
        'x-user-id': context.userId,
      },
      body: JSON.stringify(input),
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`ACCOUNTING_POST_FAILED:${body}`);
    }

    const json = (await response.json()) as { voucherId?: string; data?: { voucherId?: string } };
    const voucherId = json.voucherId ?? json.data?.voucherId;
    if (!voucherId) {
      throw new Error('ACCOUNTING_POST_FAILED:Missing voucherId');
    }

    return { voucherId };
  }
}
