import type { ImportEntity } from '../types';

export interface ImportFieldDef {
  key: string;
  label: string;
  required?: boolean;
}

export const IMPORT_FIELDS: Record<ImportEntity, ImportFieldDef[]> = {
  ledgers: [
    { key: 'name', label: 'Ledger Name', required: true },
    { key: 'group', label: 'Under Group' },
    { key: 'gstin', label: 'GSTIN' },
    { key: 'openingBalance', label: 'Opening Balance' },
  ],
  items: [
    { key: 'name', label: 'Item Name', required: true },
    { key: 'hsn', label: 'HSN/SAC' },
    { key: 'unit', label: 'Unit' },
    { key: 'rate', label: 'Rate' },
    { key: 'gstPercent', label: 'GST %' },
    { key: 'category', label: 'Category' },
  ],
  stock: [
    { key: 'name', label: 'Item Name', required: true },
    { key: 'stockQty', label: 'Closing Stock Qty' },
    { key: 'rate', label: 'Rate' },
  ],
  purchases: [
    { key: 'invoiceNo', label: 'Invoice No.', required: true },
    { key: 'invoiceDate', label: 'Invoice Date' },
    { key: 'partyName', label: 'Party / Supplier Name', required: true },
    { key: 'partyGSTIN', label: 'Party GSTIN' },
    { key: 'placeOfSupply', label: 'Place of Supply' },
    { key: 'itemName', label: 'Item Name', required: true },
    { key: 'hsn', label: 'HSN/SAC' },
    { key: 'unit', label: 'Unit' },
    { key: 'qty', label: 'Qty', required: true },
    { key: 'rate', label: 'Rate', required: true },
    { key: 'gstPercent', label: 'GST %' },
  ],
};

/** Billing-software adaptation presets: known label the user picks in the UI. */
export const IMPORT_SOFTWARE_PRESETS = ['Generic / CSV', 'Tally', 'Busy', 'Marg', 'Vyapar', 'Zoho Books'] as const;
export type ImportSoftwarePreset = (typeof IMPORT_SOFTWARE_PRESETS)[number];

/** Normalized (lowercase, alphanumeric-only) header aliases recognised across common billing software exports. */
const ALIASES: Record<ImportEntity, Record<string, string[]>> = {
  ledgers: {
    name: ['name', 'ledgername', 'accountname', 'partyname', 'ledger', 'account', 'acname'],
    group: ['group', 'undergroup', 'ledgergroup', 'accountgroup', 'under', 'parent'],
    gstin: ['gstin', 'gstno', 'gstnumber', 'gstuin', 'gstinuin'],
    openingBalance: ['openingbalance', 'opbalance', 'openingbal', 'balance', 'openingamount'],
  },
  items: {
    name: ['itemname', 'stockitemname', 'productname', 'name', 'item', 'description'],
    hsn: ['hsn', 'hsncode', 'hsnsac', 'sac', 'hsnsaccode'],
    unit: ['unit', 'uom', 'units', 'unitofmeasure', 'baseunit'],
    rate: ['rate', 'price', 'sellingrate', 'standardrate', 'mrp', 'salesrate'],
    gstPercent: ['gst', 'gstrate', 'gstpercent', 'taxrate', 'gstpercentage', 'igst'],
    category: ['category', 'stockgroup', 'itemgroup', 'productcategory', 'group'],
  },
  stock: {
    name: ['itemname', 'stockitemname', 'productname', 'name', 'item'],
    stockQty: ['closingstock', 'closingqty', 'stockqty', 'qty', 'quantity', 'closingbalance', 'currentstock'],
    rate: ['rate', 'price', 'sellingrate', 'standardrate', 'valuationrate'],
  },
  purchases: {
    invoiceNo: ['invoiceno', 'billno', 'voucherno', 'invoicenumber', 'billnumber', 'referenceno'],
    invoiceDate: ['invoicedate', 'billdate', 'date', 'voucherdate'],
    partyName: ['partyname', 'suppliername', 'vendorname', 'accountname', 'ledgername', 'partya/cname'],
    partyGSTIN: ['partygstin', 'suppliergstin', 'vendorgstin', 'gstin', 'gstno'],
    placeOfSupply: ['placeofsupply', 'pos', 'state', 'consigneestate'],
    itemName: ['itemname', 'productname', 'stockitemname', 'description'],
    hsn: ['hsn', 'hsncode', 'hsnsac', 'sac'],
    unit: ['unit', 'uom', 'units'],
    qty: ['qty', 'quantity', 'billedqty'],
    rate: ['rate', 'price', 'purchaserate'],
    gstPercent: ['gst', 'gstrate', 'gstpercent', 'taxrate'],
  },
};

function normalizeHeader(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]/g, '');
}

/**
 * Auto-maps CSV headers to target field keys for the given entity, by fuzzy-matching
 * normalized header text against known aliases from common billing software exports
 * (Tally, Busy, Marg, Vyapar, Zoho, generic). Returns { fieldKey: headerIndex }.
 */
export function autoMapHeaders(entity: ImportEntity, headers: string[]): Record<string, number> {
  const aliasSet = ALIASES[entity];
  const mapping: Record<string, number> = {};
  const normalizedHeaders = headers.map(normalizeHeader);

  for (const field of IMPORT_FIELDS[entity]) {
    const aliases = aliasSet[field.key] ?? [field.key];
    const idx = normalizedHeaders.findIndex((h) => aliases.includes(h));
    if (idx !== -1) mapping[field.key] = idx;
  }
  return mapping;
}
