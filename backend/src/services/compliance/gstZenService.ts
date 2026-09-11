import { env } from '../../config/env.js';
import {
  parseGstZenCancelEWayBillOnIrnPayload,
  parseGstZenEInvoicePayload,
  parseGstZenEWayBillOnIrnPayload,
  parseGstZenGetEInvoicePayload,
  parseGstZenStandaloneEWayBillPayload,
} from './gstZenSchemas.js';

export interface GstZenConfig {
  accountEmail?: string;
  token?: string;
  baseUrl: string;
  ewayBillBaseUrl: string;
  gstinValidatorUrl: string;
}

type GstZenAction =
  | 'version'
  | 'generate-einvoice'
  | 'cancel-einvoice'
  | 'generate-eway-bill'
  | 'cancel-eway-bill';

const actionPaths: Record<GstZenAction, string> = {
  version: 'version/',
  'generate-einvoice': '',
  'cancel-einvoice': 'cancel/',
  'generate-eway-bill': 'genewb/',
  'cancel-eway-bill': 'cancelewb/',
};

export class GstZenService {
  constructor(
    private readonly config: GstZenConfig = {
      accountEmail: env.GSTZEN_ACCOUNT_EMAIL,
      token: env.GSTZEN_TOKEN,
      baseUrl: env.GSTZEN_BASE_URL,
      ewayBillBaseUrl: env.GSTZEN_EWAY_BILL_BASE_URL,
      gstinValidatorUrl: env.GSTZEN_GSTIN_VALIDATOR_URL,
    },
    private readonly fetcher: typeof fetch = fetch,
  ) {}

  get status() {
    return {
      provider: 'GSTZen',
      configured: this.isConfigured,
      accountEmail: this.config.accountEmail ?? null,
    };
  }

  get isConfigured(): boolean {
    return Boolean(this.config.accountEmail?.trim() && this.config.token?.trim());
  }

  version() {
    return this.request('version');
  }

  async generateEInvoice(payload: Record<string, unknown>) {
    return this.request('generate-einvoice', parseGstZenEInvoicePayload(payload));
  }

  cancelEInvoice(payload: Record<string, unknown>) {
    return this.request('cancel-einvoice', payload);
  }

  async getEInvoice(payload: Record<string, unknown>) {
    return this.requestAt(
      this.config.baseUrl,
      'geteinv/',
      'POST',
      parseGstZenGetEInvoicePayload(payload),
    );
  }

  async generateEWayBill(payload: Record<string, unknown>) {
    return this.request(
      'generate-eway-bill',
      parseGstZenEWayBillOnIrnPayload(payload),
    );
  }

  async cancelEWayBill(payload: Record<string, unknown>) {
    return this.request(
      'cancel-eway-bill',
      parseGstZenCancelEWayBillOnIrnPayload(payload),
    );
  }

  createEWayBill(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'generate/',
      parseGstZenStandaloneEWayBillPayload('create', payload),
      gstin,
    );
  }

  cancelStandaloneEWayBill(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'cancel/',
      parseGstZenStandaloneEWayBillPayload('cancel', payload),
      gstin,
    );
  }

  updateEWayBillPartB(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'update-partb/',
      parseGstZenStandaloneEWayBillPayload('updatePartB', payload),
      gstin,
    );
  }

  updateEWayBillTransporter(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'update-transporter/',
      parseGstZenStandaloneEWayBillPayload('updateTransporter', payload),
      gstin,
    );
  }

  getEWayBill(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'getewb/',
      parseGstZenStandaloneEWayBillPayload('get', payload),
      gstin,
    );
  }

  generateConsolidatedEWayBill(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'consolidate/',
      parseGstZenStandaloneEWayBillPayload('consolidate', payload),
      gstin,
    );
  }

  getConsolidatedEWayBill(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'get-consolidated/',
      parseGstZenStandaloneEWayBillPayload('getConsolidated', payload),
      gstin,
    );
  }

  extendEWayBill(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'extend/',
      parseGstZenStandaloneEWayBillPayload('extend', payload),
      gstin,
    );
  }

  initiateMultiVehicleMovement(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'initiate-multi-vehicle-movement/',
      parseGstZenStandaloneEWayBillPayload('initiateMultiVehicle', payload),
      gstin,
    );
  }

  addMultiVehicles(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'add-multi-vehicles/',
      parseGstZenStandaloneEWayBillPayload('addMultiVehicle', payload),
      gstin,
    );
  }

  changeMultiVehicles(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'change-multi-vehicles/',
      parseGstZenStandaloneEWayBillPayload('changeMultiVehicle', payload),
      gstin,
    );
  }

  closeEWayBill(payload: Record<string, unknown>, gstin: string) {
    return this.ewayBillRequest(
      'closure/',
      parseGstZenStandaloneEWayBillPayload('close', payload),
      gstin,
    );
  }

  getTransporterView(query: Record<string, string>) {
    return this.ewayBillQuery('get-ewb-transporter-view/', query);
  }

  getTransporterStateView(query: Record<string, string>) {
    return this.ewayBillQuery('get-ewb-transporter-state-view/', query);
  }

  getTransporterGstinView(query: Record<string, string>) {
    return this.ewayBillQuery('get-ewb-transporter-gstin-view/', query);
  }

  validateGstin(value: string) {
    const gstin = this.normalizeGstin(value);
    return this.requestUrl(this.config.gstinValidatorUrl, 'POST', { gstin });
  }

  private async request(
    action: GstZenAction,
    payload?: Record<string, unknown>,
  ): Promise<unknown> {
    return this.requestAt(
      this.config.baseUrl,
      actionPaths[action],
      action === 'version' ? 'GET' : 'POST',
      payload,
    );
  }

  private ewayBillRequest(
    path: string,
    payload: Record<string, unknown>,
    gstin: string,
  ) {
    const normalizedGstin = this.normalizeGstin(gstin);
    return this.requestAt(
      this.config.ewayBillBaseUrl,
      path,
      'POST',
      payload,
      { gstin: normalizedGstin },
    );
  }

  private ewayBillQuery(path: string, query: Record<string, string>) {
    const normalizedQuery = Object.fromEntries(
      Object.entries(query).filter(([, value]) => value.trim().length > 0),
    );
    this.normalizeGstin(normalizedQuery.gstin ?? '');
    const search = new URLSearchParams(normalizedQuery).toString();
    return this.requestAt(
      this.config.ewayBillBaseUrl,
      `${path}?${search}`,
      'GET',
    );
  }

  private normalizeGstin(value: string): string {
    const gstin = value.trim().toUpperCase();
    if (!/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][A-Z0-9]Z[A-Z0-9]$/.test(gstin)) {
      throw new Error('GSTZEN_INVALID_GSTIN');
    }
    return gstin;
  }

  private async requestAt(
    baseUrlValue: string,
    path: string,
    method: 'GET' | 'POST',
    payload?: Record<string, unknown>,
    extraHeaders: Record<string, string> = {},
  ): Promise<unknown> {
    if (!this.isConfigured) {
      throw new Error('CONFIGURATION_REQUIRED:GSTZEN_ACCOUNT_EMAIL,GSTZEN_TOKEN');
    }

    const baseUrl = baseUrlValue.replace(/\/+$/, '');
    return this.requestUrl(`${baseUrl}/${path}`, method, payload, extraHeaders);
  }

  private async requestUrl(
    url: string,
    method: 'GET' | 'POST',
    payload?: Record<string, unknown>,
    extraHeaders: Record<string, string> = {},
  ): Promise<unknown> {
    if (!this.isConfigured) {
      throw new Error('CONFIGURATION_REQUIRED:GSTZEN_ACCOUNT_EMAIL,GSTZEN_TOKEN');
    }

    const response = await this.fetcher(url, {
      method,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        Token: this.config.token!.trim(),
        ...extraHeaders,
      },
      body: payload === undefined ? undefined : JSON.stringify(payload),
    });

    const responseText = await response.text();
    const body = this.parseBody(responseText);
    if (!response.ok || this.isProviderFailure(body)) {
      const detail = this.providerMessage(body) ?? `HTTP ${response.status}`;
      throw new Error(`GSTZEN_REQUEST_FAILED:${detail}`);
    }

    return body;
  }

  private parseBody(value: string): unknown {
    if (!value.trim()) return {};
    try {
      return JSON.parse(value) as unknown;
    } catch {
      return { message: value };
    }
  }

  private isProviderFailure(body: unknown): boolean {
    if (typeof body !== 'object' || body === null) return false;
    const status = (body as Record<string, unknown>).status;
    return status === 0 || status === '0' || status === false;
  }

  private providerMessage(body: unknown): string | null {
    if (typeof body !== 'object' || body === null) return null;
    const message = (body as Record<string, unknown>).message;
    return typeof message === 'string' && message.trim() ? message.trim() : null;
  }
}