import { useRef } from 'react';
import type { LedgerEntry } from '../types';
import { useMasters } from '../context/MastersContext';
import { computeLedgerTotals, createEmptyLedgerRow, formatINR } from '../utils/calculations';

interface Props {
  voucherLabel: string;
  rows: LedgerEntry[];
  onRowsChange: (rows: LedgerEntry[]) => void;
  onNotify?: (message: string, kind: 'success' | 'error') => void;
  onAlterLedger?: (id: string) => void;
}

type Col = 'ledgerName' | 'drAmount' | 'crAmount' | 'narration';
const COLS: Col[] = ['ledgerName', 'drAmount', 'crAmount', 'narration'];

let idCounter = 1;
const nextId = () => `ledger-${Date.now()}-${idCounter++}`;

export default function LedgerVoucherEntry({ voucherLabel, rows, onRowsChange, onNotify, onAlterLedger }: Props) {
  const { ledgers, addLedger, isDuplicateLedgerName } = useMasters();
  const inputRefs = useRef<Record<string, HTMLInputElement | null>>({});

  const setRef = (rowId: string, col: Col) => (el: HTMLInputElement | null) => {
    inputRefs.current[`${rowId}:${col}`] = el;
  };

  const focusCell = (rowId: string, col: Col) => {
    const el = inputRefs.current[`${rowId}:${col}`];
    el?.focus();
    el?.select();
  };

  function updateRow(rowId: string, patch: Partial<LedgerEntry>) {
    onRowsChange(rows.map((r) => (r.id === rowId ? { ...r, ...patch } : r)));
  }

  function addRow(focusNew = true) {
    const row = createEmptyLedgerRow(nextId());
    onRowsChange([...rows, row]);
    if (focusNew) setTimeout(() => focusCell(row.id, 'ledgerName'), 0);
    return row;
  }

  function removeRow(rowId: string) {
    if (rows.length === 1) {
      onRowsChange([createEmptyLedgerRow(nextId())]);
      return;
    }
    onRowsChange(rows.filter((r) => r.id !== rowId));
  }

  function moveToNext(rowIndex: number, colIndex: number) {
    const isLastCol = colIndex === COLS.length - 1;
    if (!isLastCol) {
      focusCell(rows[rowIndex].id, COLS[colIndex + 1]);
      return;
    }
    if (rowIndex === rows.length - 1) {
      const row = addRow(false);
      setTimeout(() => focusCell(row.id, 'ledgerName'), 0);
    } else {
      focusCell(rows[rowIndex + 1].id, COLS[0]);
    }
  }

  function handleKeyDown(e: React.KeyboardEvent, rowIndex: number, colIndex: number) {
    if (e.key === 'Enter') {
      e.preventDefault();
      moveToNext(rowIndex, colIndex);
    }
  }

  function handleLedgerNameKeyDown(e: React.KeyboardEvent, row: LedgerEntry, rowIndex: number) {
    if (e.altKey && e.key.toLowerCase() === 'c') {
      e.preventDefault();
      const name = row.ledgerName.trim();
      if (!name) return;
      if (isDuplicateLedgerName(name)) {
        onNotify?.(`"${name}" already exists. Use Alt+A to alter it.`, 'error');
        return;
      }
      const result = addLedger({
        name,
        group: 'Sundry Debtors',
        gstin: '',
        gstRegistrationType: 'Unregistered/URP',
        openingBalance: 0,
      });
      if (result.ok) {
        onNotify?.(`Ledger "${name}" created and added to master.`, 'success');
      } else {
        onNotify?.(result.error ?? 'Could not create ledger.', 'error');
      }
      return;
    }
    if (e.altKey && e.key.toLowerCase() === 'a') {
      e.preventDefault();
      const master = ledgers.find((l) => l.name.toLowerCase() === row.ledgerName.trim().toLowerCase());
      if (master && onAlterLedger) {
        onAlterLedger(master.id);
      } else {
        onNotify?.('Type an existing ledger name to alter it.', 'error');
      }
      return;
    }
    handleKeyDown(e, rowIndex, 0);
  }

  const totals = computeLedgerTotals(rows);
  const inputCls =
    'w-full rounded border-none bg-transparent px-2 py-1.5 text-[12.5px] outline-none focus:bg-blue-50 focus:ring-1 focus:ring-blue-400';

  return (
    <div className="flex-1 overflow-auto px-5 pt-3">
      <table className="voucher-table text-sm">
        <thead>
          <tr className="bg-slate-100 text-[11px] font-semibold uppercase text-slate-600">
            <th className="w-10 px-2 py-2">S.No</th>
            <th className="min-w-[220px] px-2 py-2 text-left">Ledger Account ({voucherLabel})</th>
            <th className="w-32 px-2 py-2">Debit</th>
            <th className="w-32 px-2 py-2">Credit</th>
            <th className="min-w-[180px] px-2 py-2 text-left">Narration</th>
            <th className="w-8 px-1 py-2"></th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr key={row.id} className="bg-white hover:bg-slate-50">
              <td className="text-center text-slate-500">{rowIndex + 1}</td>
              <td>
                <input
                  ref={setRef(row.id, 'ledgerName')}
                  className={inputCls}
                  value={row.ledgerName}
                  list={`ledger-master-${row.id}`}
                  onChange={(e) => updateRow(row.id, { ledgerName: e.target.value })}
                  onKeyDown={(e) => handleLedgerNameKeyDown(e, row, rowIndex)}
                  placeholder="Select / type ledger... (Alt+C create, Alt+A alter)"
                  title="Alt+C: create if new · Alt+A: alter existing"
                />
                <datalist id={`ledger-master-${row.id}`}>
                  {ledgers.map((l) => (
                    <option key={l.id} value={l.name} />
                  ))}
                </datalist>
              </td>
              <td>
                <input
                  ref={setRef(row.id, 'drAmount')}
                  type="number"
                  className={`${inputCls} text-right`}
                  value={row.drAmount || ''}
                  onChange={(e) =>
                    updateRow(row.id, { drAmount: Number(e.target.value) || 0, crAmount: e.target.value ? 0 : row.crAmount })
                  }
                  onKeyDown={(e) => handleKeyDown(e, rowIndex, 1)}
                />
              </td>
              <td>
                <input
                  ref={setRef(row.id, 'crAmount')}
                  type="number"
                  className={`${inputCls} text-right`}
                  value={row.crAmount || ''}
                  onChange={(e) =>
                    updateRow(row.id, { crAmount: Number(e.target.value) || 0, drAmount: e.target.value ? 0 : row.drAmount })
                  }
                  onKeyDown={(e) => handleKeyDown(e, rowIndex, 2)}
                />
              </td>
              <td>
                <input
                  ref={setRef(row.id, 'narration')}
                  className={inputCls}
                  value={row.narration}
                  onChange={(e) => updateRow(row.id, { narration: e.target.value })}
                  onKeyDown={(e) => handleKeyDown(e, rowIndex, 3)}
                />
              </td>
              <td className="text-center">
                <button
                  onClick={() => removeRow(row.id)}
                  className="text-slate-400 hover:text-rose-600"
                  title="Remove row"
                  aria-label="Remove row"
                >
                  ✕
                </button>
              </td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr className="bg-slate-50 font-semibold text-slate-700">
            <td className="px-2 py-2 text-right" colSpan={2}>
              Total
            </td>
            <td className="px-2 py-2 text-right">{formatINR(totals.totalDr)}</td>
            <td className="px-2 py-2 text-right">{formatINR(totals.totalCr)}</td>
            <td colSpan={2}></td>
          </tr>
        </tfoot>
      </table>
      <div className="mt-2 mb-4 flex items-center justify-between">
        <button
          onClick={() => addRow()}
          className="flex items-center gap-1 rounded-md border border-dashed border-slate-300 px-3 py-1.5 text-xs font-medium text-slate-500 hover:border-blue-400 hover:text-blue-600"
        >
          + Add Row
        </button>
        <div
          className={`rounded-md px-3 py-1.5 text-xs font-semibold ${
            totals.balanced ? 'bg-emerald-50 text-emerald-700' : 'bg-amber-50 text-amber-700'
          }`}
        >
          {totals.balanced
            ? '✓ Debit and Credit are balanced'
            : `⚠ Difference: ₹ ${formatINR(Math.abs(totals.difference))} ${totals.difference > 0 ? '(excess Dr)' : '(excess Cr)'}`}
        </div>
      </div>
    </div>
  );
}
