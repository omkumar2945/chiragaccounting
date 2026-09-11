import type { ItemMasterEntry, ItemCategoryEntry, LedgerMasterEntry, UnitMasterEntry } from '../types';

/** The company's home state — used to decide CGST+SGST vs IGST split. */
export const HOME_STATE = 'Karnataka';

export const ITEM_MASTER_SEED: ItemMasterEntry[] = [
  { id: 'seed-item-1', name: 'Product A', barcode: '890123456001', hsn: '8471', unit: 'Nos', rate: 500, gstPercent: 18, category: 'Electronics', stockQty: 120 },
  { id: 'seed-item-2', name: 'Product B', barcode: '890123456002', hsn: '8473', unit: 'Nos', rate: 800, gstPercent: 18, category: 'Electronics', stockQty: 80 },
  { id: 'seed-item-3', name: 'Item A', barcode: '890123456003', hsn: '8517', unit: 'Nos', rate: 450, gstPercent: 18, category: 'Electronics', stockQty: 60 },
  { id: 'seed-item-4', name: 'Item B', barcode: '890123456004', hsn: '8517', unit: 'Nos', rate: 700, gstPercent: 18, category: 'Electronics', stockQty: 40 },
  { id: 'seed-item-5', name: 'Steel Rod 12mm', barcode: '890123456005', hsn: '7214', unit: 'Kg', rate: 62, gstPercent: 18, category: 'Construction Material', stockQty: 500 },
  { id: 'seed-item-6', name: 'Cement OPC 53', barcode: '890123456006', hsn: '2523', unit: 'Bag', rate: 380, gstPercent: 28, category: 'Construction Material', stockQty: 200 },
  { id: 'seed-item-7', name: 'HDPE Pipe 2"', barcode: '890123456007', hsn: '3917', unit: 'Mtr', rate: 145, gstPercent: 18, category: 'Construction Material', stockQty: 300 },
  { id: 'seed-item-8', name: 'Copper Wire 1.5mm', barcode: '890123456008', hsn: '8544', unit: 'Roll', rate: 1250, gstPercent: 18, category: 'Hardware', stockQty: 25 },
  { id: 'seed-item-9', name: 'LED Bulb 9W', barcode: '890123456009', hsn: '8539', unit: 'Nos', rate: 95, gstPercent: 12, category: 'Hardware', stockQty: 400 },
  { id: 'seed-item-10', name: 'Plywood 18mm', barcode: '890123456010', hsn: '4412', unit: 'Sheet', rate: 2100, gstPercent: 18, category: 'Construction Material', stockQty: 30 },
];

export const UNITS = ['Nos', 'Kg', 'Bag', 'Mtr', 'Roll', 'Sheet', 'Box', 'Ltr', 'Set'];

export const UNIT_MASTER_SEED: UnitMasterEntry[] = UNITS.map((name, i) => ({ id: `seed-unit-${i + 1}`, name }));

export const ITEM_CATEGORY_SEED: ItemCategoryEntry[] = [
  { id: 'seed-cat-1', name: 'General' },
  { id: 'seed-cat-2', name: 'Electronics' },
  { id: 'seed-cat-3', name: 'Hardware' },
  { id: 'seed-cat-4', name: 'Construction Material' },
];

export const INDIAN_STATES = [
  'Andaman and Nicobar Islands', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam',
  'Bihar', 'Chandigarh', 'Chhattisgarh', 'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jammu and Kashmir',
  'Jharkhand', 'Karnataka', 'Kerala', 'Ladakh', 'Lakshadweep', 'Madhya Pradesh',
  'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha',
  'Puducherry', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana',
  'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
];

export const PARTY_SUGGESTIONS = [
  { name: 'ABC TRADERS', gstin: '29AAACB1234F1Z5' },
  { name: 'XYZ SUPPLIERS', gstin: '29AAACX5678K1Z2' },
  { name: 'SUNRISE ENTERPRISES', gstin: '29AABCS9988M1Z7' },
  { name: 'GLOBAL HARDWARE CO.', gstin: '27AACFG2211P1Z3' },
];

export const LEDGER_MASTER_SEED: LedgerMasterEntry[] = [
  { id: 'seed-ledger-1', name: 'Cash A/c', group: 'Cash-in-Hand', gstin: '', gstRegistrationType: 'Unregistered/URP', openingBalance: 0 },
  { id: 'seed-ledger-2', name: 'Bank A/c - HDFC Current', group: 'Bank Accounts', gstin: '', gstRegistrationType: 'Unregistered/URP', openingBalance: 0 },
  { id: 'seed-ledger-3', name: 'Bank A/c - SBI Current', group: 'Bank Accounts', gstin: '', gstRegistrationType: 'Unregistered/URP', openingBalance: 0 },
  { id: 'seed-ledger-4', name: 'Sales A/c - GST 18%', group: 'Sales Accounts', gstin: '', gstRegistrationType: 'Regular', openingBalance: 0 },
  { id: 'seed-ledger-5', name: 'Purchase A/c - GST 18%', group: 'Purchase Accounts', gstin: '', gstRegistrationType: 'Regular', openingBalance: 0 },
  { id: 'seed-ledger-6', name: 'ABC TRADERS', group: 'Sundry Debtors', gstin: '29AAACB1234F1Z5', gstRegistrationType: 'Regular', openingBalance: 0 },
  { id: 'seed-ledger-7', name: 'XYZ SUPPLIERS', group: 'Sundry Creditors', gstin: '29AAACX5678K1Z2', gstRegistrationType: 'Regular', openingBalance: 0 },
  { id: 'seed-ledger-8', name: 'SUNRISE ENTERPRISES', group: 'Sundry Debtors', gstin: '29AABCS9988M1Z7', gstRegistrationType: 'Regular', openingBalance: 0 },
  { id: 'seed-ledger-9', name: 'GLOBAL HARDWARE CO.', group: 'Sundry Creditors', gstin: '27AACFG2211P1Z3', gstRegistrationType: 'Regular', openingBalance: 0 },
  { id: 'seed-ledger-10', name: 'Salary A/c', group: 'Indirect Expenses', gstin: '', gstRegistrationType: 'Unregistered/URP', openingBalance: 0 },
  { id: 'seed-ledger-11', name: 'Rent A/c', group: 'Indirect Expenses', gstin: '', gstRegistrationType: 'Unregistered/URP', openingBalance: 0 },
  { id: 'seed-ledger-12', name: 'Office Expenses A/c', group: 'Indirect Expenses', gstin: '', gstRegistrationType: 'Unregistered/URP', openingBalance: 0 },
  { id: 'seed-ledger-13', name: 'Freight & Cartage A/c', group: 'Direct Expenses', gstin: '', gstRegistrationType: 'Unregistered/URP', openingBalance: 0 },
  { id: 'seed-ledger-14', name: 'Discount Allowed A/c', group: 'Indirect Expenses', gstin: '', gstRegistrationType: 'Unregistered/URP', openingBalance: 0 },
  { id: 'seed-ledger-15', name: 'Discount Received A/c', group: 'Indirect Expenses', gstin: '', gstRegistrationType: 'Unregistered/URP', openingBalance: 0 },
  { id: 'seed-ledger-16', name: 'Round Off A/c', group: 'Indirect Expenses', gstin: '', gstRegistrationType: 'Unregistered/URP', openingBalance: 0 },
  { id: 'seed-ledger-17', name: 'Input CGST A/c', group: 'Duties & Taxes', gstin: '', gstRegistrationType: 'Regular', openingBalance: 0 },
  { id: 'seed-ledger-18', name: 'Input SGST A/c', group: 'Duties & Taxes', gstin: '', gstRegistrationType: 'Regular', openingBalance: 0 },
  { id: 'seed-ledger-19', name: 'Input IGST A/c', group: 'Duties & Taxes', gstin: '', gstRegistrationType: 'Regular', openingBalance: 0 },
  { id: 'seed-ledger-20', name: 'Output CGST A/c', group: 'Duties & Taxes', gstin: '', gstRegistrationType: 'Regular', openingBalance: 0 },
  { id: 'seed-ledger-21', name: 'Output SGST A/c', group: 'Duties & Taxes', gstin: '', gstRegistrationType: 'Regular', openingBalance: 0 },
  { id: 'seed-ledger-22', name: 'Output IGST A/c', group: 'Duties & Taxes', gstin: '', gstRegistrationType: 'Regular', openingBalance: 0 },
];

export const GODOWNS = ['Main Godown', 'Branch Godown', 'Warehouse A', 'Warehouse B'];
