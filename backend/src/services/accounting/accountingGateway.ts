import { SecurityContext } from '../../types/securityContext.js';

export interface DraftSalesInvoice {
  customer: string;
  item: string;
  quantity: number;
  unit: string;
  rate: number;
  deliveryLocation: string;
  transporter: string;
  vehicleNumber: string;
  total: number;
}

export interface AccountingGateway {
  postSalesInvoice(input: DraftSalesInvoice, context: SecurityContext): Promise<{ voucherId: string }>;
}
