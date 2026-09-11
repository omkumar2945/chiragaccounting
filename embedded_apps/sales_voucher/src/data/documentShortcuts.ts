export interface DocumentShortcut {
  document: string;
  shortcutLabel: string;
  key: string;
  matches: (e: KeyboardEvent) => boolean;
}

function altShortcut(document: string, key: string): DocumentShortcut {
  return {
    document,
    shortcutLabel: `Alt+${key.toUpperCase()}`,
    key,
    matches: (e) => e.altKey && !e.ctrlKey && e.key.toLowerCase() === key.toLowerCase(),
  };
}

/** Extra business-template voucher/document types, shown after the fixed vouchers with their own Alt+key shortcut. */
export const DOCUMENT_SHORTCUTS: DocumentShortcut[] = [
  altShortcut('Quotation', 'q'),
  altShortcut('Estimate', 'e'),
  altShortcut('Proforma Invoice', 'i'),
  altShortcut('Sales Order', 's'),
  altShortcut('Purchase Order', 'p'),
  altShortcut('Delivery Challan', 'd'),
  altShortcut('Material Inward', 'm'),
  altShortcut('Material Outward', 'o'),
  altShortcut('Job Work Inward', 'j'),
  altShortcut('Job Work Outward', 'k'),
  altShortcut('Goods Receipt', 'g'),
  altShortcut('Goods Return', 'r'),
  altShortcut('Purchase Return', 'u'),
  altShortcut('Sales Return', 'n'),
  altShortcut('Production', 'x'),
  altShortcut('Consumption', 'c'),
  altShortcut('Service Order', 'v'),
  altShortcut('Work Order', 'w'),
];
