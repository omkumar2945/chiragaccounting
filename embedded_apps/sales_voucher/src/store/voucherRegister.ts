import type { VoucherRegisterEntry, VoucherType } from '../types';

const STORAGE_KEY = 'chirag_voucher_register_v1';

function load(): VoucherRegisterEntry[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw) as VoucherRegisterEntry[];
  } catch {
    /* ignore corrupted storage */
  }
  return [];
}

function persist(list: VoucherRegisterEntry[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
}

function normalize(invoiceNo: string): string {
  return invoiceNo.trim().toLowerCase();
}

/** Returns true if this invoice number is already used by a saved voucher of the same type. */
export function isDuplicateInvoiceNo(voucherType: VoucherType, invoiceNo: string): boolean {
  const n = normalize(invoiceNo);
  if (!n) return false;
  return load().some((v) => v.voucherType === voucherType && normalize(v.invoiceNo) === n);
}

export function registerVoucher(entry: Omit<VoucherRegisterEntry, 'savedAt'>) {
  const list = load();
  list.push({ ...entry, savedAt: new Date().toISOString() });
  persist(list);
}

export function listVouchers(): VoucherRegisterEntry[] {
  return load().sort((a, b) => {
    const dateCompare = (b.voucherDate ?? b.savedAt).localeCompare(a.voucherDate ?? a.savedAt);
    return dateCompare || b.savedAt.localeCompare(a.savedAt);
  });
}
