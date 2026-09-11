import type { VoucherType } from '../types';

export interface VoucherNumberSeries {
  prefix: string;
  mode: 'auto' | 'manual';
  nextNumber: number;
  locked: boolean;
}

type NumberingStore = Record<string, Partial<Record<VoucherType, VoucherNumberSeries>>>;

const STORAGE_KEY = 'chirag_voucher_numbering_v1';

const DEFAULT_PREFIX: Record<VoucherType, string> = {
  Sales: 'SI', Purchase: 'PU', 'Debit Note': 'DN', 'Credit Note': 'CN', Payment: 'PMT', Receipt: 'RCT', Journal: 'JV', Contra: 'CTR', 'Stock Journal': 'STJ', 'Manufacturing Journal': 'MFG',
};

export function financialYear(date = new Date()): string {
  const startYear = date.getMonth() >= 3 ? date.getFullYear() : date.getFullYear() - 1;
  return `${String(startYear).slice(-2)}-${String(startYear + 1).slice(-2)}`;
}

function load(): NumberingStore {
  try { return JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '{}') as NumberingStore; } catch { return {}; }
}

function save(store: NumberingStore) { localStorage.setItem(STORAGE_KEY, JSON.stringify(store)); }

export function getSeries(type: VoucherType, fy = financialYear()): VoucherNumberSeries {
  return load()[fy]?.[type] ?? { prefix: DEFAULT_PREFIX[type], mode: 'auto', nextNumber: 1, locked: false };
}

export function saveSeries(type: VoucherType, series: VoucherNumberSeries, fy = financialYear()): { ok: boolean; error?: string } {
  const current = getSeries(type, fy);
  if (current.locked) return { ok: false, error: `${type} numbering is locked because vouchers already exist in FY ${fy}.` };
  const prefix = series.prefix.trim().toUpperCase();
  if (!/^[A-Z0-9]{1,10}$/.test(prefix)) return { ok: false, error: 'Prefix must contain 1-10 letters or numbers.' };
  if (!Number.isInteger(series.nextNumber) || series.nextNumber < 1) return { ok: false, error: 'Starting number must be 1 or higher.' };
  const store = load();
  store[fy] = { ...store[fy], [type]: { ...series, prefix } };
  save(store);
  return { ok: true };
}

export function makeVoucherNumber(type: VoucherType, date?: string): string {
  const parsed = date ? new Date(`${date}T00:00:00`) : new Date();
  const fy = financialYear(Number.isNaN(parsed.getTime()) ? new Date() : parsed);
  const series = getSeries(type, fy);
  return `${series.prefix}/${fy}/${String(series.nextNumber).padStart(4, '0')}`;
}

export function isAutomaticNumber(type: VoucherType, date?: string): boolean {
  const parsed = date ? new Date(`${date}T00:00:00`) : new Date();
  return getSeries(type, financialYear(Number.isNaN(parsed.getTime()) ? new Date() : parsed)).mode === 'auto';
}

export function markNumberUsed(type: VoucherType, date?: string) {
  const parsed = date ? new Date(`${date}T00:00:00`) : new Date();
  const fy = financialYear(Number.isNaN(parsed.getTime()) ? new Date() : parsed);
  const series = getSeries(type, fy);
  const store = load();
  store[fy] = { ...store[fy], [type]: { ...series, nextNumber: series.nextNumber + 1, locked: true } };
  save(store);
}