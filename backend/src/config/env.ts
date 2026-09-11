import { createPrivateKey } from 'node:crypto';
import { readFileSync } from 'node:fs';
import dotenv from 'dotenv';
import type { ServiceAccount } from 'firebase-admin/app';
import { z } from 'zod';

dotenv.config();

const schema = z.object({
	NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
	PORT: z.coerce.number().default(3000),
	JWT_SECRET: z.string().min(1),
	DB_HOST: z.string().min(1),
	DB_PORT: z.coerce.number().int().positive().default(3306),
	DB_USER: z.string().min(1),
	DB_PASSWORD: z.string().min(1),
	DB_NAME: z.string().min(1),
	FIREBASE_SERVICE_ACCOUNT_JSON: z.string().min(1).optional(),
	FIREBASE_SERVICE_ACCOUNT_PATH: z.string().min(1).optional(),
	MSSQL_SERVER: z.string().min(1),
	MSSQL_PORT: z.coerce.number().default(1433),
	MSSQL_DATABASE: z.string().min(1),
	MSSQL_USER: z.string().min(1),	
	MSSQL_PASSWORD: z.string().min(1),
	MSSQL_ENCRYPT: z.string().default('false'),
	MSSQL_TRUST_CERT: z.string().default('true'),
	SMTP_HOST: z.string().min(1).optional(),
	SMTP_PORT: z.coerce.number().int().positive().default(587),
	SMTP_SECURE: z.string().default('false'),
	SMTP_USER: z.string().min(1).optional(),
	SMTP_PASSWORD: z.string().min(1).optional(),
	SMTP_FROM: z.string().email().optional(),
	ACCOUNTING_PROVIDER: z.string().default('erp_http'),
	ACCOUNTING_API_BASE_URL: z.string().optional(),
	ACCOUNTING_API_TOKEN: z.string().optional(),
	EINVOICE_API_URL: z.string().optional(),
	EINVOICE_API_KEY: z.string().optional(),
	EWAY_API_URL: z.string().optional(),
	EWAY_API_KEY: z.string().optional(),
	GSTZEN_ACCOUNT_EMAIL: z.string().email().optional(),
	GSTZEN_TOKEN: z.string().optional(),
	GSTZEN_API_TOKEN: z.string().optional(),
	GSTZEN_BASE_URL: z.string().url().default(
		'https://my.gstzen.in/~gstzen/a/post-einvoice-data/einvoice-json',
	),
	GSTZEN_EWAY_BILL_BASE_URL: z.string().url().default(
		'https://my.gstzen.in/~gstzen/a/ewbapi',
	),
	GSTZEN_GSTIN_VALIDATOR_URL: z.string().url().default(
		'https://my.gstzen.in/api/gstin-validator/',
	),
	GSTZEN_GSTR1_API_URL: z.string().url().optional(),
	GSTZEN_GSTR1_RETSAVE_API_URL: z.string().url().optional(),
	GSTZEN_GSTR1_RESET_API_URL: z.string().url().optional(),
	GSTZEN_GSTR1_GSTRPTF_API_URL: z.string().url().optional(),
	GSTZEN_GSTR1_RETFILE_DSC_API_URL: z.string().url().optional(),
	GSTZEN_GSTR1A_API_URL_RETSAVE: z.string().url().optional(),
	GSTZEN_GSTR1A_API_URL_DOWNLOAD: z.string().url().optional(),
	GSTZEN_GSTR1A_API_URL_RESET: z.string().url().optional(),
	GSTZEN_GSTR1A_API_URL_GSTRPTF: z.string().url().optional(),
	GSTZEN_GSTR1A_API_URL_RETSTATUS: z.string().url().optional(),
	GSTZEN_GSTR2_B2B_API_URL: z.string().url().optional(),
	GSTZEN_GSTR2_B2BA_API_URL: z.string().url().optional(),
	GSTZEN_GSTR2_CDN_API_URL: z.string().url().optional(),
	GSTZEN_GSTR2_CDNA_API_URL: z.string().url().optional(),
	GSTZEN_GSTR2_IMPG_API_URL: z.string().url().optional(),
	GSTZEN_GSTR2_IMPGSEZ_API_URL: z.string().url().optional(),
	GSTZEN_GSTR2_ISD_API_URL: z.string().url().optional(),
	GSTZEN_GSTR2_2B_API_URL: z.string().url().optional(),
	GSTZEN_GSTR2_TDSTCS_API_URL: z.string().url().optional(),
	GSTZEN_GSTR2_ECOM_API_URL: z.string().url().optional(),
	GSTZEN_GSTR2_ECOMA_API_URL: z.string().url().optional(),
	GSTZEN_GSTR3B_AUTOLIAB_API_URL: z.string().url().optional(),
	GSTZEN_GSTR3B_RETINT_API_URL: z.string().url().optional(),
	GSTZEN_GSTR3B_RETSAVE_API_URL: z.string().url().optional(),
	GSTZEN_GSTR3B_RETOFFSET_API_URL: z.string().url().optional(),
	GSTZEN_GSTR3B_RETSUM_API_URL: z.string().url().optional(),
	GSTZEN_GSTR3B_CASHITCBALANCE_API_URL: z.string().url().optional(),
	GSTZEN_IMS_API_URL: z.string().url().optional(),
	GSTZEN_IMS_API_URL_GET_INVOICES_COUNT: z.string().url().optional(),
	GSTZEN_IMS_API_URL_GET_FILE_DETAILS: z.string().url().optional(),
	GSTZEN_IMS_API_URL_SAVE_ACTIONS: z.string().url().optional(),
	GSTZEN_IMS_API_URL_RESET_ACTIONS: z.string().url().optional(),
	GSTZEN_IMS_API_URL_GET_REQ_STATUS: z.string().url().optional(),
	GSTZEN_RETSTATUS_API_URL: z.string().url().optional(),
	GSTZEN_GSTN_GENERATE_OTP_API_URL: z.string().url().optional(),
	GSTZEN_GSTN_GENERATE_EVC_OTP_API_URL: z.string().url().optional(),
	GSTZEN_GSTN_ESTABLISH_SESSION_API_URL: z.string().url().optional(),
	GSTZEN_GSTN_REFRESH_SESSION_API_URL: z.string().url().optional(),
	GSTZEN_FILEDET_API_URL: z.string().url().optional(),
	GSTZEN_DOWNLOAD_API_URL: z.string().url().optional(),
	GSTZEN_DELETE_INVOICE_API_URL: z.string().url().optional(),
	GSTZEN_LOGIN_TOKEN_API_URL: z.string().url().optional(),
	GSTZEN_CREATE_GSTIN_API_URL: z.string().url().optional(),
	GSTZEN_EINVOICE_LOGIN_SESSION_API_URL: z.string().url().optional(),
	GSTZEN_POST_PURCHASE_DATA_API_URL: z.string().url().optional(),
	GSTZEN_GET_RECONCILIATION_STATUS_API_URL: z.string().url().optional(),
	GSTZEN_SIGN_PDF_API_URL: z.string().url().optional(),
	PORTAL_CREDENTIAL_ENCRYPTION_KEY: z.string().regex(/^[a-fA-F0-9]{64}$/).optional(),
	PRINTER_API_URL: z.string().optional(),
	PRINTER_API_KEY: z.string().optional(),
	LOCATION_API_URL: z.string().url().optional(),
	LOCATION_API_KEY: z.string().optional(),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
	throw new Error(`Invalid environment configuration: ${parsed.error.message}`);
}

const firebaseServiceAccountJson = parsed.data.FIREBASE_SERVICE_ACCOUNT_PATH
	? readFileSync(parsed.data.FIREBASE_SERVICE_ACCOUNT_PATH, 'utf8')
	: parsed.data.FIREBASE_SERVICE_ACCOUNT_JSON;

export const firebaseServiceAccount = parsed.data.NODE_ENV === 'test'
	? undefined
	: firebaseServiceAccountJson
	? parseFirebaseServiceAccount(firebaseServiceAccountJson)
	: undefined;

function parseFirebaseServiceAccount(serviceAccountJson: string): ServiceAccount {
	let account: Record<string, unknown>;
	try {
		const parsedAccount: unknown = JSON.parse(serviceAccountJson);
		if (typeof parsedAccount !== 'object' || parsedAccount === null) {
			throw new Error('Service account must be a JSON object.');
		}
		account = parsedAccount as Record<string, unknown>;
	} catch (error) {
		throw new Error(`Invalid Firebase service-account JSON: ${error instanceof Error ? error.message : String(error)}`);
	}

	for (const field of ['project_id', 'client_email', 'private_key'] as const) {
		if (typeof account[field] !== 'string' || account[field].trim().length === 0) {
			throw new Error(`Invalid Firebase service-account JSON: ${field} is required.`);
		}
	}

	try {
		createPrivateKey(account.private_key as string);
	} catch (error) {
		throw new Error(`Invalid Firebase service-account private key: ${error instanceof Error ? error.message : String(error)}`);
	}

	return account as ServiceAccount;
}

export const env = {
	...parsed.data,
	MSSQL_ENCRYPT: parsed.data.MSSQL_ENCRYPT === 'true',
	MSSQL_TRUST_CERT: parsed.data.MSSQL_TRUST_CERT === 'true',
	SMTP_SECURE: parsed.data.SMTP_SECURE === 'true',
};
