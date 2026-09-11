import type { VoucherType } from '../types';

export interface VoucherShortcut {
  type: VoucherType;
  shortcutLabel: string;
  matches: (e: KeyboardEvent) => boolean;
}

/** Tally-style function-key shortcuts for switching the active voucher type. */
export const VOUCHER_SHORTCUTS: VoucherShortcut[] = [
  { type: 'Contra', shortcutLabel: 'F4', matches: (e) => e.key === 'F4' && !e.ctrlKey && !e.altKey },
  { type: 'Payment', shortcutLabel: 'F5', matches: (e) => e.key === 'F5' && !e.ctrlKey && !e.altKey },
  { type: 'Receipt', shortcutLabel: 'F6', matches: (e) => e.key === 'F6' && !e.ctrlKey && !e.altKey },
  { type: 'Journal', shortcutLabel: 'F7', matches: (e) => e.key === 'F7' && !e.ctrlKey && !e.altKey },
  { type: 'Sales', shortcutLabel: 'F8', matches: (e) => e.key === 'F8' && !e.ctrlKey && !e.altKey },
  { type: 'Purchase', shortcutLabel: 'F9', matches: (e) => e.key === 'F9' && !e.ctrlKey && !e.altKey },
  { type: 'Credit Note', shortcutLabel: 'Ctrl+F8', matches: (e) => e.key === 'F8' && e.ctrlKey },
  { type: 'Debit Note', shortcutLabel: 'Ctrl+F9', matches: (e) => e.key === 'F9' && e.ctrlKey },
  { type: 'Stock Journal', shortcutLabel: 'Alt+F7', matches: (e) => e.key === 'F7' && e.altKey },
  { type: 'Manufacturing Journal', shortcutLabel: 'Alt+F8', matches: (e) => e.key === 'F8' && e.altKey },
];
