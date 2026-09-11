import type { ItemRow, ItemTotals, LedgerEntry, ManufacturingMaterialRow, ManufacturingOutput, StockEntryRow, VoucherTotals } from '../types';
import { HOME_STATE } from '../data/masters';

/** Rounds to 2 decimal places, avoiding floating-point artifacts. */
export function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

export function computeRowTotals(row: ItemRow): ItemTotals {
  const gross = row.qty * row.rate;
  const discountAmount = gross * (row.discountPercent / 100);
  const taxableValue = round2(gross - discountAmount);
  const gstAmount = taxableValue * (row.gstPercent / 100);

  return {
    taxableValue,
    cgst: 0,
    sgst: 0,
    igst: 0,
    total: round2(taxableValue + gstAmount),
  };
}

export function computeRowGstSplit(row: ItemRow, placeOfSupply: string): ItemTotals {
  const base = computeRowTotals(row);
  const interState = placeOfSupply.trim() !== '' && placeOfSupply.trim() !== HOME_STATE;
  const gstAmount = round2(base.total - base.taxableValue);

  if (interState) {
    return { ...base, igst: gstAmount, cgst: 0, sgst: 0 };
  }
  return { ...base, cgst: round2(gstAmount / 2), sgst: round2(gstAmount / 2), igst: 0 };
}

export function computeVoucherTotals(rows: ItemRow[], placeOfSupply: string): VoucherTotals {
  let taxableAmount = 0;
  let cgst = 0;
  let sgst = 0;
  let igst = 0;

  for (const row of rows) {
    const t = computeRowGstSplit(row, placeOfSupply);
    taxableAmount += t.taxableValue;
    cgst += t.cgst;
    sgst += t.sgst;
    igst += t.igst;
  }

  const preRoundTotal = taxableAmount + cgst + sgst + igst;
  const grandTotal = Math.round(preRoundTotal);
  const roundOff = round2(grandTotal - preRoundTotal);

  return {
    taxableAmount: round2(taxableAmount),
    cgst: round2(cgst),
    sgst: round2(sgst),
    igst: round2(igst),
    roundOff,
    grandTotal,
  };
}

export function formatINR(n: number): string {
  return n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

export function createEmptyRow(id: string): ItemRow {
  return {
    id,
    itemName: '',
    hsn: '',
    qty: 0,
    unit: 'Nos',
    rate: 0,
    discountPercent: 0,
    gstPercent: 18,
    overridden: false,
  };
}

export function createEmptyLedgerRow(id: string): LedgerEntry {
  return { id, ledgerName: '', drAmount: 0, crAmount: 0, narration: '' };
}

export function createEmptyStockRow(id: string): StockEntryRow {
  return { id, itemName: '', unit: 'Nos', fromGodown: 'Main Godown', toGodown: 'Branch Godown', qty: 0, rate: 0 };
}

export function createEmptyManufacturingMaterialRow(id: string): ManufacturingMaterialRow {
  return { id, itemName: '', unit: 'Nos', godown: 'Main Godown', qty: 0, rate: 0 };
}

export function createEmptyManufacturingOutput(): ManufacturingOutput {
  return { itemName: '', unit: 'Nos', godown: 'Main Godown', qty: 0, rate: 0 };
}

export function computeLedgerTotals(rows: LedgerEntry[]) {
  const totalDr = round2(rows.reduce((s, r) => s + (r.drAmount || 0), 0));
  const totalCr = round2(rows.reduce((s, r) => s + (r.crAmount || 0), 0));
  return { totalDr, totalCr, difference: round2(totalDr - totalCr), balanced: round2(totalDr - totalCr) === 0 };
}

export function computeStockTotals(rows: StockEntryRow[]) {
  const totalQty = rows.reduce((s, r) => s + (r.qty || 0), 0);
  const totalValue = round2(rows.reduce((s, r) => s + (r.qty || 0) * (r.rate || 0), 0));
  return { totalQty, totalValue };
}
