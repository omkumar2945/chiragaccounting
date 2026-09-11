import { env } from '../../config/env.js';

export type GstComplianceOperation =
  | 'gstr1-download'
  | 'gstr1-save'
  | 'gstr1-reset'
  | 'gstr1-file'
  | 'gstr1a-download'
  | 'gstr1a-save'
  | 'gstr1a-reset'
  | 'gstr1a-file'
  | 'gstr1a-status'
  | 'gstr2-b2b'
  | 'gstr2-b2ba'
  | 'gstr2-cdn'
  | 'gstr2-cdna'
  | 'gstr2-impg'
  | 'gstr2-impgsez'
  | 'gstr2-isd'
  | 'gstr2-2b'
  | 'gstr2-tdstcs'
  | 'gstr2-ecom'
  | 'gstr2-ecoma'
  | 'gstr3b-auto-liability'
  | 'gstr3b-interest'
  | 'gstr3b-save'
  | 'gstr3b-offset'
  | 'gstr3b-summary'
  | 'gstr3b-cash-itc-balance'
  | 'ims'
  | 'ims-invoice-count'
  | 'ims-file-details'
  | 'ims-save-actions'
  | 'ims-reset-actions'
  | 'ims-request-status'
  | 'return-status'
  | 'generate-otp'
  | 'generate-evc-otp'
  | 'establish-session'
  | 'refresh-session'
  | 'file-details'
  | 'download'
  | 'delete-invoice'
  | 'login-token'
  | 'create-gstin'
  | 'einvoice-login-session'
  | 'post-purchase-data'
  | 'reconciliation-status'
  | 'sign-pdf';

const operationUrls: Record<GstComplianceOperation, () => string | undefined> = {
  'gstr1-download': () => env.GSTZEN_GSTR1_API_URL,
  'gstr1-save': () => env.GSTZEN_GSTR1_RETSAVE_API_URL,
  'gstr1-reset': () => env.GSTZEN_GSTR1_RESET_API_URL,
  'gstr1-file': () => env.GSTZEN_GSTR1_GSTRPTF_API_URL,
  'gstr1a-download': () => env.GSTZEN_GSTR1A_API_URL_DOWNLOAD,
  'gstr1a-save': () => env.GSTZEN_GSTR1A_API_URL_RETSAVE,
  'gstr1a-reset': () => env.GSTZEN_GSTR1A_API_URL_RESET,
  'gstr1a-file': () => env.GSTZEN_GSTR1A_API_URL_GSTRPTF,
  'gstr1a-status': () => env.GSTZEN_GSTR1A_API_URL_RETSTATUS,
  'gstr2-b2b': () => env.GSTZEN_GSTR2_B2B_API_URL,
  'gstr2-b2ba': () => env.GSTZEN_GSTR2_B2BA_API_URL,
  'gstr2-cdn': () => env.GSTZEN_GSTR2_CDN_API_URL,
  'gstr2-cdna': () => env.GSTZEN_GSTR2_CDNA_API_URL,
  'gstr2-impg': () => env.GSTZEN_GSTR2_IMPG_API_URL,
  'gstr2-impgsez': () => env.GSTZEN_GSTR2_IMPGSEZ_API_URL,
  'gstr2-isd': () => env.GSTZEN_GSTR2_ISD_API_URL,
  'gstr2-2b': () => env.GSTZEN_GSTR2_2B_API_URL,
  'gstr2-tdstcs': () => env.GSTZEN_GSTR2_TDSTCS_API_URL,
  'gstr2-ecom': () => env.GSTZEN_GSTR2_ECOM_API_URL,
  'gstr2-ecoma': () => env.GSTZEN_GSTR2_ECOMA_API_URL,
  'gstr3b-auto-liability': () => env.GSTZEN_GSTR3B_AUTOLIAB_API_URL,
  'gstr3b-interest': () => env.GSTZEN_GSTR3B_RETINT_API_URL,
  'gstr3b-save': () => env.GSTZEN_GSTR3B_RETSAVE_API_URL,
  'gstr3b-offset': () => env.GSTZEN_GSTR3B_RETOFFSET_API_URL,
  'gstr3b-summary': () => env.GSTZEN_GSTR3B_RETSUM_API_URL,
  'gstr3b-cash-itc-balance': () => env.GSTZEN_GSTR3B_CASHITCBALANCE_API_URL,
  ims: () => env.GSTZEN_IMS_API_URL,
  'ims-invoice-count': () => env.GSTZEN_IMS_API_URL_GET_INVOICES_COUNT,
  'ims-file-details': () => env.GSTZEN_IMS_API_URL_GET_FILE_DETAILS,
  'ims-save-actions': () => env.GSTZEN_IMS_API_URL_SAVE_ACTIONS,
  'ims-reset-actions': () => env.GSTZEN_IMS_API_URL_RESET_ACTIONS,
  'ims-request-status': () => env.GSTZEN_IMS_API_URL_GET_REQ_STATUS,
  'return-status': () => env.GSTZEN_RETSTATUS_API_URL,
  'generate-otp': () => env.GSTZEN_GSTN_GENERATE_OTP_API_URL,
  'generate-evc-otp': () => env.GSTZEN_GSTN_GENERATE_EVC_OTP_API_URL,
  'establish-session': () => env.GSTZEN_GSTN_ESTABLISH_SESSION_API_URL,
  'refresh-session': () => env.GSTZEN_GSTN_REFRESH_SESSION_API_URL,
  'file-details': () => env.GSTZEN_FILEDET_API_URL,
  download: () => env.GSTZEN_DOWNLOAD_API_URL,
  'delete-invoice': () => env.GSTZEN_DELETE_INVOICE_API_URL,
  'login-token': () => env.GSTZEN_LOGIN_TOKEN_API_URL,
  'create-gstin': () => env.GSTZEN_CREATE_GSTIN_API_URL,
  'einvoice-login-session': () => env.GSTZEN_EINVOICE_LOGIN_SESSION_API_URL,
  'post-purchase-data': () => env.GSTZEN_POST_PURCHASE_DATA_API_URL,
  'reconciliation-status': () => env.GSTZEN_GET_RECONCILIATION_STATUS_API_URL,
  'sign-pdf': () => env.GSTZEN_SIGN_PDF_API_URL,
};

export class GstComplianceGatewayService {
  constructor(private readonly fetcher: typeof fetch = fetch) {}

  async execute(operation: GstComplianceOperation, payload: Record<string, unknown>) {
    const url = operationUrls[operation]();
    const token = env.GSTZEN_TOKEN?.trim() || env.GSTZEN_API_TOKEN?.trim();
    if (!url) throw new Error(`CONFIGURATION_REQUIRED:${operation}`);
    if (!token) throw new Error('CONFIGURATION_REQUIRED:GSTZEN_TOKEN');

    const response = await this.fetcher(url, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        Token: token,
      },
      body: JSON.stringify(payload),
    });
    const text = await response.text();
    let body: unknown = {};
    try {
      body = text.trim() ? JSON.parse(text) : {};
    } catch {
      body = { message: text };
    }
    if (!response.ok) {
      const message =
        typeof body === 'object' && body !== null && 'message' in body
          ? String((body as Record<string, unknown>).message)
          : `HTTP ${response.status}`;
      throw new Error(`GSTZEN_REQUEST_FAILED:${message}`);
    }
    return body;
  }
}