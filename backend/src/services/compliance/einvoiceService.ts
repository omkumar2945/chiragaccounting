import { GstZenService } from './gstZenService.js';

export class EInvoiceService {
  constructor(private readonly gstZen = new GstZenService()) {}

  async generate(payload: Record<string, unknown>) {
    return this.gstZen.generateEInvoice(payload);
  }

  async cancel(payload: Record<string, unknown>) {
    return this.gstZen.cancelEInvoice(payload);
  }
}
