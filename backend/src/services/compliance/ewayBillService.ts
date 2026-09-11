import { GstZenService } from './gstZenService.js';

export class EWayBillService {
  constructor(private readonly gstZen = new GstZenService()) {}

  async generate(payload: Record<string, unknown>) {
    return this.gstZen.generateEWayBill(payload);
  }

  async cancel(payload: Record<string, unknown>) {
    return this.gstZen.cancelEWayBill(payload);
  }
}
