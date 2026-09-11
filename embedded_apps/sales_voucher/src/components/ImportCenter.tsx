import { useRef, useState } from 'react';
import type { ImportEntity, ItemRow, PurchaseImportRow, VoucherHeaderData } from '../types';
import { IMPORT_FIELDS, IMPORT_SOFTWARE_PRESETS, autoMapHeaders } from '../data/importPresets';
import { parseCsvWithHeaders } from '../utils/csv';
import { useMasters } from '../context/MastersContext';
import { isDuplicateInvoiceNo, registerVoucher } from '../store/voucherRegister';

interface Props {
  onClose: () => void;
  /** Auto-pulls the first successfully imported purchase invoice into the active voucher screen. */
  onAutoPullPurchase: (header: Partial<VoucherHeaderData>, rows: ItemRow[]) => void;
}

const TAB_LABEL: Record<ImportEntity, string> = {
  ledgers: 'Ledgers',
  items: 'Items',
  stock: 'Closing Stock',
  purchases: 'Purchases (Auto-pull)',
};

const TAB_HINT: Record<ImportEntity, string> = {
  ledgers: 'Import your Chart of Accounts / party ledgers from another billing system.',
  items: 'Import your stock item / product master from another billing system.',
  stock: 'Update closing stock quantities for existing items, or create new items with their stock on hand.',
  purchases: 'Auto-pull purchase invoices into this system — matching parties and items are linked, missing ones are auto-created under the correct standards.',
};

export default function ImportCenter({ onClose, onAutoPullPurchase }: Props) {
  const {
    ledgers,
    items,
    addLedger,
    addItem,
    updateItem,
    findItemByName,
    addUnit,
    isDuplicateUnitName,
    addCategory,
    isDuplicateCategoryName,
  } = useMasters();

  const [tab, setTab] = useState<ImportEntity>('ledgers');
  const [preset, setPreset] = useState<(typeof IMPORT_SOFTWARE_PRESETS)[number]>('Generic / CSV');
  const [fileName, setFileName] = useState<string | null>(null);
  const [headers, setHeaders] = useState<string[]>([]);
  const [rows, setRows] = useState<string[][]>([]);
  const [mapping, setMapping] = useState<Record<string, number>>({});
  const [summary, setSummary] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  function switchTab(t: ImportEntity) {
    setTab(t);
    setFileName(null);
    setHeaders([]);
    setRows([]);
    setMapping({});
    setSummary(null);
    setError(null);
  }

  function handleFile(file: File) {
    const reader = new FileReader();
    reader.onload = () => {
      const text = String(reader.result ?? '');
      const parsed = parseCsvWithHeaders(text);
      setFileName(file.name);
      setHeaders(parsed.headers);
      setRows(parsed.rows);
      setMapping(autoMapHeaders(tab, parsed.headers));
      setSummary(null);
      setError(null);
    };
    reader.readAsText(file);
  }

  function cellValue(row: string[], fieldKey: string): string {
    const idx = mapping[fieldKey];
    return idx !== undefined ? (row[idx] ?? '').trim() : '';
  }

  function ensureUnit(name: string) {
    const trimmed = name.trim();
    if (trimmed && !isDuplicateUnitName(trimmed)) addUnit(trimmed);
  }

  function ensureCategory(name: string) {
    const trimmed = name.trim();
    if (trimmed && !isDuplicateCategoryName(trimmed)) addCategory(trimmed);
  }

  function runImport() {
    if (rows.length === 0) {
      setError('Upload a CSV file first.');
      return;
    }
    const requiredMissing = IMPORT_FIELDS[tab].filter((f) => f.required && mapping[f.key] === undefined);
    if (requiredMissing.length > 0) {
      setError(`Map the required field(s): ${requiredMissing.map((f) => f.label).join(', ')}.`);
      return;
    }

    let created = 0;
    let skipped = 0;

    // Track names created during this run locally, since context state won't
    // re-render mid-loop (avoids creating duplicate ledgers/items within one batch).
    const seenLedgerNames = new Set(ledgers.map((l) => l.name.trim().toLowerCase()));
    const seenItemNames = new Set(items.map((i) => i.name.trim().toLowerCase()));

    if (tab === 'ledgers') {
      for (const row of rows) {
        const name = cellValue(row, 'name');
        if (!name) continue;
        const key = name.trim().toLowerCase();
        if (seenLedgerNames.has(key)) {
          skipped++;
          continue;
        }
        const gstin = cellValue(row, 'gstin');
        const group = cellValue(row, 'group') || 'Sundry Debtors';
        const result = addLedger({
          name,
          group: group as never,
          gstin,
          gstRegistrationType: gstin ? 'Regular' : 'Unregistered/URP',
          openingBalance: Number(cellValue(row, 'openingBalance')) || 0,
        });
        if (result.ok) {
          created++;
          seenLedgerNames.add(key);
        } else skipped++;
      }
      setSummary(`Imported ${created} ledger(s). Skipped ${skipped} duplicate/invalid row(s).`);
    } else if (tab === 'items') {
      for (const row of rows) {
        const name = cellValue(row, 'name');
        const key = name.trim().toLowerCase();
        if (!name || seenItemNames.has(key)) {
          if (name) skipped++;
          continue;
        }
        const unit = cellValue(row, 'unit') || 'Nos';
        const category = cellValue(row, 'category');
        ensureUnit(unit);
        ensureCategory(category);
        const result = addItem({
          name,
          barcode: cellValue(row, 'barcode') || '',
          hsn: cellValue(row, 'hsn'),
          unit,
          rate: Number(cellValue(row, 'rate')) || 0,
          gstPercent: Number(cellValue(row, 'gstPercent')) || 0,
          category,
          stockQty: 0,
        });
        if (result.ok) {
          created++;
          seenItemNames.add(key);
        } else skipped++;
      }
      setSummary(`Imported ${created} item(s). Skipped ${skipped} duplicate/invalid row(s).`);
    } else if (tab === 'stock') {
      let updated = 0;
      for (const row of rows) {
        const name = cellValue(row, 'name');
        if (!name) continue;
        const key = name.trim().toLowerCase();
        const stockQty = Number(cellValue(row, 'stockQty')) || 0;
        const rate = Number(cellValue(row, 'rate')) || 0;
        const existing = findItemByName(name);
        if (existing) {
          updateItem(existing.id, { ...existing, stockQty, rate: rate || existing.rate });
          updated++;
        } else if (!seenItemNames.has(key)) {
          addItem({ name, barcode: '', hsn: '', unit: 'Nos', rate, gstPercent: 18, category: '', stockQty });
          created++;
          seenItemNames.add(key);
        } else {
          skipped++;
        }
      }
      setSummary(`Updated closing stock for ${updated} item(s), created ${created} new item(s).`);
    } else {
      const purchaseRows: PurchaseImportRow[] = rows
        .map((row) => ({
          invoiceNo: cellValue(row, 'invoiceNo'),
          invoiceDate: cellValue(row, 'invoiceDate'),
          partyName: cellValue(row, 'partyName'),
          partyGSTIN: cellValue(row, 'partyGSTIN'),
          placeOfSupply: cellValue(row, 'placeOfSupply') || 'Karnataka',
          itemName: cellValue(row, 'itemName'),
          hsn: cellValue(row, 'hsn'),
          unit: cellValue(row, 'unit') || 'Nos',
          qty: Number(cellValue(row, 'qty')) || 0,
          rate: Number(cellValue(row, 'rate')) || 0,
          gstPercent: Number(cellValue(row, 'gstPercent')) || 18,
        }))
        .filter((r) => r.invoiceNo && r.itemName && r.qty > 0);

      const byInvoice = new Map<string, PurchaseImportRow[]>();
      for (const r of purchaseRows) {
        const group = byInvoice.get(r.invoiceNo) ?? [];
        group.push(r);
        byInvoice.set(r.invoiceNo, group);
      }

      let invoices = 0;
      let ledgersCreated = 0;
      let itemsCreated = 0;
      let firstInvoice: PurchaseImportRow[] | null = null;

      for (const [invoiceNo, lines] of byInvoice) {
        if (isDuplicateInvoiceNo('Purchase', invoiceNo)) {
          skipped++;
          continue;
        }
        const partyName = lines[0].partyName;
        const partyKey = partyName.trim().toLowerCase();
        if (partyName && !seenLedgerNames.has(partyKey)) {
          const gstin = lines[0].partyGSTIN;
          const result = addLedger({
            name: partyName,
            group: 'Sundry Creditors' as never,
            gstin,
            gstRegistrationType: gstin ? 'Regular' : 'Unregistered/URP',
            openingBalance: 0,
          });
          if (result.ok) {
            ledgersCreated++;
            seenLedgerNames.add(partyKey);
          }
        }
        for (const line of lines) {
          const itemKey = line.itemName.trim().toLowerCase();
          if (line.itemName && !findItemByName(line.itemName) && !seenItemNames.has(itemKey)) {
            ensureUnit(line.unit);
            const result = addItem({
              name: line.itemName,
              barcode: '',
              hsn: line.hsn,
              unit: line.unit,
              rate: line.rate,
              gstPercent: line.gstPercent,
              category: '',
              stockQty: 0,
            });
            if (result.ok) {
              itemsCreated++;
              seenItemNames.add(itemKey);
            }
          }
        }
        registerVoucher({ voucherType: 'Purchase', invoiceNo, voucherNo: `PU-IMP-${invoiceNo}` });
        invoices++;
        if (!firstInvoice) firstInvoice = lines;
      }

      if (firstInvoice) {
        const first = firstInvoice[0];
        onAutoPullPurchase(
          {
            partyName: first.partyName,
            partyGSTIN: first.partyGSTIN,
            invoiceNo: first.invoiceNo,
            invoiceDate: first.invoiceDate || new Date().toISOString().slice(0, 10),
            placeOfSupply: first.placeOfSupply,
          },
          firstInvoice.map((line, i) => ({
            id: `imported-${i}`,
            itemName: line.itemName,
            hsn: line.hsn,
            qty: line.qty,
            unit: line.unit,
            rate: line.rate,
            discountPercent: 0,
            gstPercent: line.gstPercent,
            overridden: false,
          }))
        );
      }

      setSummary(
        `Auto-pulled ${invoices} purchase invoice(s). Auto-created ${ledgersCreated} supplier ledger(s) and ${itemsCreated} item(s). Skipped ${skipped} duplicate invoice(s).${
          firstInvoice ? ' The first invoice has been loaded into the Purchase voucher screen for review.' : ''
        }`
      );
    }

    setError(null);
  }

  const inputCls =
    'w-full rounded-md border border-slate-300 bg-white px-2.5 py-1.5 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100';
  const label = 'block text-[11px] font-semibold uppercase tracking-wide text-slate-500 mb-1';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-6">
      <div className="flex h-full max-h-[760px] w-full max-w-5xl flex-col rounded-lg bg-white shadow-2xl">
        <div className="flex items-center justify-between border-b border-slate-200 px-5 py-3">
          <h2 className="text-sm font-bold uppercase tracking-wide text-slate-700">
            Import / Integration Center — Adapt from Existing Billing Software
          </h2>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-700" aria-label="Close">
            ✕
          </button>
        </div>

        <div className="flex border-b border-slate-200 px-5">
          {(['ledgers', 'items', 'stock', 'purchases'] as ImportEntity[]).map((t) => (
            <button
              key={t}
              onClick={() => switchTab(t)}
              className={`border-b-2 px-4 py-2 text-xs font-semibold uppercase tracking-wide ${
                tab === t ? 'border-blue-600 text-blue-700' : 'border-transparent text-slate-400 hover:text-slate-600'
              }`}
            >
              {TAB_LABEL[t]}
            </button>
          ))}
        </div>

        <div className="flex-1 overflow-auto p-5">
          <p className="mb-4 text-xs text-slate-500">{TAB_HINT[tab]}</p>

          <div className="mb-4 grid grid-cols-3 gap-3">
            <div>
              <label className={label}>Source Billing Software</label>
              <select className={inputCls} value={preset} onChange={(e) => setPreset(e.target.value as never)}>
                {IMPORT_SOFTWARE_PRESETS.map((p) => (
                  <option key={p} value={p}>
                    {p}
                  </option>
                ))}
              </select>
            </div>
            <div className="col-span-2">
              <label className={label}>CSV File</label>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => fileInputRef.current?.click()}
                  className="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-600 hover:bg-slate-50"
                >
                  Choose CSV…
                </button>
                <span className="text-xs text-slate-500">{fileName ?? 'No file selected'}</span>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".csv,text/csv"
                  className="hidden"
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) handleFile(f);
                  }}
                />
              </div>
            </div>
          </div>

          {error && <div className="mb-3 rounded-md bg-rose-50 px-3 py-2 text-xs font-medium text-rose-700">⚠ {error}</div>}
          {summary && (
            <div className="mb-3 rounded-md bg-emerald-50 px-3 py-2 text-xs font-medium text-emerald-700">✓ {summary}</div>
          )}

          {headers.length > 0 && (
            <>
              <h3 className="mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">
                Column Mapping — {preset} columns adapted to our standard fields
              </h3>
              <div className="mb-4 grid grid-cols-3 gap-3 rounded-md border border-slate-200 bg-slate-50 p-3">
                {IMPORT_FIELDS[tab].map((field) => (
                  <div key={field.key}>
                    <label className={label}>
                      {field.label}
                      {field.required && <span className="text-rose-500"> *</span>}
                    </label>
                    <select
                      className={inputCls}
                      value={mapping[field.key] ?? ''}
                      onChange={(e) =>
                        setMapping((m) => ({
                          ...m,
                          [field.key]: e.target.value === '' ? undefined : Number(e.target.value),
                        }) as Record<string, number>)
                      }
                    >
                      <option value="">— Not mapped —</option>
                      {headers.map((h, idx) => (
                        <option key={h + idx} value={idx}>
                          {h}
                        </option>
                      ))}
                    </select>
                  </div>
                ))}
              </div>

              <h3 className="mb-2 text-xs font-bold uppercase tracking-wide text-slate-600">
                Preview ({rows.length} row(s) detected)
              </h3>
              <div className="mb-4 max-h-56 overflow-auto rounded-md border border-slate-200">
                <table className="w-full text-xs">
                  <thead className="sticky top-0 bg-slate-100 font-semibold uppercase text-slate-600">
                    <tr>
                      {IMPORT_FIELDS[tab].map((field) => (
                        <th key={field.key} className="px-2 py-1.5 text-left">
                          {field.label}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {rows.slice(0, 8).map((row, i) => (
                      <tr key={i} className="border-t border-slate-100">
                        {IMPORT_FIELDS[tab].map((field) => (
                          <td key={field.key} className="px-2 py-1.5">
                            {cellValue(row, field.key) || '—'}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <button
                onClick={runImport}
                className="rounded-md bg-blue-600 px-5 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-700"
              >
                {tab === 'purchases' ? 'Auto-pull Purchases' : `Import ${TAB_LABEL[tab]}`}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
