export type VoucherType =
  | 'Sales'
  | 'Purchase'
  | 'Debit Note'
  | 'Credit Note'
  | 'Payment'
  | 'Receipt'
  | 'Journal'
  | 'Contra'
  | 'Stock Journal'
  | 'Manufacturing Journal';

/** Voucher types that use the invoice-style item grid + GST totals layout. */
export const ITEM_VOUCHER_TYPES: VoucherType[] = ['Sales', 'Purchase', 'Debit Note', 'Credit Note'];
/** Voucher types that use the plain Dr/Cr ledger entry grid. */
export const LEDGER_VOUCHER_TYPES: VoucherType[] = ['Payment', 'Receipt', 'Journal', 'Contra'];
/** Voucher types that use the stock movement grid (no GST/party ledger). */
export const STOCK_VOUCHER_TYPES: VoucherType[] = ['Stock Journal'];
/** Manufacturing conversion vouchers consume a BOQ and receive finished goods. */
export const MANUFACTURING_VOUCHER_TYPES: VoucherType[] = ['Manufacturing Journal'];

export type VoucherCategory = 'item' | 'ledger' | 'stock' | 'manufacturing';

export function voucherCategory(type: VoucherType): VoucherCategory {
  if (LEDGER_VOUCHER_TYPES.includes(type)) return 'ledger';
  if (STOCK_VOUCHER_TYPES.includes(type)) return 'stock';
  if (MANUFACTURING_VOUCHER_TYPES.includes(type)) return 'manufacturing';
  return 'item';
}

export type EntryMode = 'standard' | 'ai';

export interface ClientProfile {
  clientId: string;
  clientName: string;
  firmName: string;
  email: string;
  mobile: string;
}

export interface StandardAddress {
  addressLine1: string;
  addressLine2: string;
  countryId: string;
  countryName: string;
  stateId: string;
  stateName: string;
  cityId: string;
  cityName: string;
  district: string;
  pincode: string;
  locality: string;
  postOffice: string;
  latitude?: number;
  longitude?: number;
  source: string;
}

export interface VoucherDynamicField {
  key: string;
  label: string;
  inputType: 'text' | 'number';
}

export interface VoucherTaxSuggestion {
  category: string;
  code: string;
  gstRate: number;
  description: string;
}

export interface VoucherTemplateConfiguration {
  voucherType: VoucherType;
  shortcut: string;
  category: VoucherCategory;
  dynamicFields: VoucherDynamicField[];
  units: string[];
  taxSuggestions: VoucherTaxSuggestion[];
  enabled: boolean;
  inventoryEnabled: boolean;
  printFormat: string;
}

export interface BusinessVoucherConfiguration {
  clientId: string;
  profileVersion: number;
  businessTypes: string[];
  businessNatures: string[];
  vouchers: VoucherTemplateConfiguration[];
  documents: string[];
  generatedAt: string;
}

export interface VoucherHeaderData {
  voucherNo: string;
  voucherDate: string;
  partyName: string;
  partyGSTIN: string;
  placeOfSupply: string;
  billingLocation: StandardAddress;
  shippingLocation: StandardAddress;
  invoiceNo: string;
  invoiceDate: string;
  paymentTerms: string;
  ledger: string;
  against: string;
  reason: string;
}

export interface ItemRow {
  id: string;
  itemName: string;
  hsn: string;
  qty: number;
  unit: string;
  rate: number;
  discountPercent: number;
  gstPercent: number;
  /** true when the user manually overrode a value auto-fetched from master */
  overridden: boolean;
  /** field name(s) flagged uncertain by AI extraction, needing verification */
  uncertainFields?: string[];
  attributes?: Record<string, string>;
}

export interface EwayTransportData {
  irn: string;
  ackNo: string;
  ackDate: string;
  ewayBillNo: string;
  ewayBillDate: string;
  ewayValidUpto: string;
  transporterName: string;
  transporterId: string;
  vehicleNo: string;
  modeOfTransport: 'Road' | 'Rail' | 'Air' | 'Ship';
  distanceKm: number;
  lrNo: string;
  lrDate: string;
  placeOfDelivery: string;
}

export interface ItemMaster {
  name: string;
  barcode?: string;
  hsn: string;
  unit: string;
  rate: number;
  gstPercent: number;
}

/** A stored, editable item master record (Masters > Items). */
export interface ItemMasterEntry extends ItemMaster {
  id: string;
  category: string;
  /** Closing/current stock quantity, as last imported or entered. */
  stockQty: number;
}

/** A stored, editable unit-of-measure master record (Masters > Units), e.g. Nos, Kg, Box. */
export interface UnitMasterEntry {
  id: string;
  name: string;
}

/** A stored, editable stock-item category / group master record (Masters > Categories). */
export interface ItemCategoryEntry {
  id: string;
  name: string;
}

export const LEDGER_GROUPS = [
  'Sundry Debtors',
  'Sundry Creditors',
  'Cash-in-Hand',
  'Bank Accounts',
  'Sales Accounts',
  'Purchase Accounts',
  'Direct Expenses',
  'Indirect Expenses',
  'Duties & Taxes',
  'Capital Account',
] as const;
export type LedgerGroup = (typeof LEDGER_GROUPS)[number];

export const GST_REGISTRATION_TYPES = ['Regular', 'Composition', 'Unregistered/URP'] as const;
export type GstRegistrationType = (typeof GST_REGISTRATION_TYPES)[number];

/** A stored, editable ledger master record (Masters > Ledgers). */
export interface LedgerMasterEntry {
  id: string;
  name: string;
  group: LedgerGroup;
  gstin: string;
  gstRegistrationType: GstRegistrationType;
  openingBalance: number;
  location?: StandardAddress;
  contactName?: string;
  mobile?: string;
  email?: string;
}

export interface ItemTotals {
  taxableValue: number;
  cgst: number;
  sgst: number;
  igst: number;
  total: number;
}

export interface VoucherTotals {
  taxableAmount: number;
  cgst: number;
  sgst: number;
  igst: number;
  roundOff: number;
  grandTotal: number;
}

/** A single Dr/Cr line used by Payment, Receipt, Journal and Contra vouchers. */
export interface LedgerEntry {
  id: string;
  ledgerName: string;
  drAmount: number;
  crAmount: number;
  narration: string;
}

/** A single stock movement line used by Stock Journal vouchers. */
export interface StockEntryRow {
  id: string;
  itemName: string;
  unit: string;
  fromGodown: string;
  toGodown: string;
  qty: number;
  rate: number;
}

/** A raw material line consumed by a manufacturing journal's BOQ. */
export interface ManufacturingMaterialRow {
  id: string;
  itemName: string;
  unit: string;
  godown: string;
  qty: number;
  rate: number;
}

/** The finished good received inward after raw materials are consumed. */
export interface ManufacturingOutput {
  itemName: string;
  unit: string;
  godown: string;
  qty: number;
  rate: number;
}

export interface SimpleVoucherHeaderData {
  voucherNo: string;
  voucherDate: string;
  referenceNo: string;
  narration: string;
}

/** Persisted voucher record used by Voucher Register, Day Book and Ledger Register. */
export interface VoucherRegisterEntry {
  clientId?: string;
  clientName?: string;
  firmName?: string;
  voucherType: VoucherType;
  documentType?: string;
  invoiceNo: string;
  voucherNo: string;
  taxableAmount?: number;
  grandTotal?: number;
  voucherDate?: string;
  referenceNo?: string;
  narration?: string;
  ledgerNames?: string[];
  stockMovements?: string[];
  totalAmount?: number;
  savedAt: string;
}

/** Target field keys used by the Import Center's column-mapping UI. */
export type ImportEntity = 'ledgers' | 'items' | 'stock' | 'purchases';

export interface LedgerImportRow {
  name: string;
  group: string;
  gstin: string;
  openingBalance: number;
}

export interface ItemImportRow {
  name: string;
  hsn: string;
  unit: string;
  rate: number;
  gstPercent: number;
  category: string;
}

export interface StockImportRow {
  name: string;
  stockQty: number;
  rate: number;
}

export interface PurchaseImportRow {
  invoiceNo: string;
  invoiceDate: string;
  partyName: string;
  partyGSTIN: string;
  placeOfSupply: string;
  itemName: string;
  hsn: string;
  unit: string;
  qty: number;
  rate: number;
  gstPercent: number;
}

