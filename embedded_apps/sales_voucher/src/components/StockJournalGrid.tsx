import { useRef } from 'react';
import type { StockEntryRow } from '../types';
import { GODOWNS, UNITS } from '../data/masters';
import { useMasters } from '../context/MastersContext';
import { computeStockTotals, createEmptyStockRow, formatINR } from '../utils/calculations';

interface Props {
  rows: StockEntryRow[];
  onRowsChange: (rows: StockEntryRow[]) => void;
  onNotify?: (message: string, kind: 'success' | 'error') => void;
  onAlterItem?: (id: string) => void;
}

type Col = 'itemName' | 'fromGodown' | 'toGodown' | 'qty' | 'unit' | 'rate';
const COLS: Col[] = ['itemName', 'fromGodown', 'toGodown', 'qty', 'unit', 'rate'];

let idCounter = 1;
const nextId = () => `stock-${Date.now()}-${idCounter++}`;

export default function StockJournalGrid({ rows, onRowsChange, onNotify, onAlterItem }: Props) {
  const { items: itemMasterList, findItemByName, searchItems, addItem } = useMasters();
  const inputRefs = useRef<Record<string, HTMLInputElement | HTMLSelectElement | null>>({});

  const setRef = (rowId: string, col: Col) => (el: HTMLInputElement | HTMLSelectElement | null) => {
    inputRefs.current[`${rowId}:${col}`] = el;
  };

  const focusCell = (rowId: string, col: Col) => {
    const el = inputRefs.current[`${rowId}:${col}`];
    el?.focus();
    if (el instanceof HTMLInputElement) el.select();
  };

  function updateRow(rowId: string, patch: Partial<StockEntryRow>) {
    onRowsChange(rows.map((r) => (r.id === rowId ? { ...r, ...patch } : r)));
  }

  function addRow(focusNew = true) {
    const row = createEmptyStockRow(nextId());
    onRowsChange([...rows, row]);
    if (focusNew) setTimeout(() => focusCell(row.id, 'itemName'), 0);
    return row;
  }

  function removeRow(rowId: string) {
    if (rows.length === 1) {
      onRowsChange([createEmptyStockRow(nextId())]);
      return;
    }
    onRowsChange(rows.filter((r) => r.id !== rowId));
  }

  function handleItemNameSelect(rowId: string, name: string) {
    const master = findItemByName(name);
    if (master) {
      updateRow(rowId, { itemName: name, unit: master.unit, rate: master.rate });
    } else {
      updateRow(rowId, { itemName: name });
    }
  }

  function moveToNext(rowIndex: number, colIndex: number) {
    const isLastCol = colIndex === COLS.length - 1;
    if (!isLastCol) {
      focusCell(rows[rowIndex].id, COLS[colIndex + 1]);
      return;
    }
    if (rowIndex === rows.length - 1) {
      const row = addRow(false);
      setTimeout(() => focusCell(row.id, 'itemName'), 0);
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

  function handleItemNameKeyDown(e: React.KeyboardEvent, row: StockEntryRow, rowIndex: number) {
    if (e.altKey && e.key.toLowerCase() === 'c') {
      e.preventDefault();
      const name = row.itemName.trim();
      if (!name) return;
      if (findItemByName(name)) {
        onNotify?.(`"${name}" already exists. Use Alt+A to alter it.`, 'error');
        return;
      }
      const result = addItem({ name, barcode: '', hsn: '', unit: row.unit, rate: row.rate, gstPercent: 18, category: '', stockQty: 0 });
      if (result.ok) {
        onNotify?.(`Item "${name}" created and added to master.`, 'success');
      } else {
        onNotify?.(result.error ?? 'Could not create item.', 'error');
      }
      return;
    }
    if (e.altKey && e.key.toLowerCase() === 'a') {
      e.preventDefault();
      const master = findItemByName(row.itemName);
      if (master && onAlterItem) {
        onAlterItem(master.id);
      } else {
        onNotify?.('Type an existing item name to alter it.', 'error');
      }
      return;
    }
    handleKeyDown(e, rowIndex, 0);
  }

  const totals = computeStockTotals(rows);
  const inputCls =
    'w-full rounded border-none bg-transparent px-2 py-1.5 text-[12.5px] outline-none focus:bg-blue-50 focus:ring-1 focus:ring-blue-400';

  return (
    <div className="flex-1 overflow-auto px-5 pt-3">
      <table className="voucher-table text-sm">
        <thead>
          <tr className="bg-slate-100 text-[11px] font-semibold uppercase text-slate-600">
            <th className="w-10 px-2 py-2">S.No</th>
            <th className="min-w-[180px] px-2 py-2 text-left">Item / Description</th>
            <th className="w-32 px-2 py-2">From Godown</th>
            <th className="w-32 px-2 py-2">To Godown</th>
            <th className="w-16 px-2 py-2">Qty</th>
            <th className="w-20 px-2 py-2">Unit</th>
            <th className="w-24 px-2 py-2">Rate</th>
            <th className="w-28 px-2 py-2">Value</th>
            <th className="w-8 px-1 py-2"></th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => {
            const suggestions = searchItems(row.itemName);
            const value = (row.qty || 0) * (row.rate || 0);
            return (
              <tr key={row.id} className="bg-white hover:bg-slate-50">
                <td className="text-center text-slate-500">{rowIndex + 1}</td>
                <td>
                  <input
                    ref={setRef(row.id, 'itemName')}
                    className={inputCls}
                    value={row.itemName}
                    list={`stock-item-master-${row.id}`}
                    onChange={(e) => handleItemNameSelect(row.id, e.target.value)}
                    onKeyDown={(e) => handleItemNameKeyDown(e, row, rowIndex)}
                    placeholder="Type item name... (Alt+C create, Alt+A alter)"
                    title="Alt+C: create if new · Alt+A: alter existing"
                  />
                  <datalist id={`stock-item-master-${row.id}`}>
                    {(suggestions.length ? suggestions : itemMasterList).map((m) => (
                      <option key={m.id} value={m.name} />
                    ))}
                  </datalist>
                </td>
                <td>
                  <select
                    ref={setRef(row.id, 'fromGodown')}
                    className={inputCls}
                    value={row.fromGodown}
                    onChange={(e) => updateRow(row.id, { fromGodown: e.target.value })}
                    onKeyDown={(e) => handleKeyDown(e, rowIndex, 1)}
                  >
                    {GODOWNS.map((g) => (
                      <option key={g} value={g}>
                        {g}
                      </option>
                    ))}
                  </select>
                </td>
                <td>
                  <select
                    ref={setRef(row.id, 'toGodown')}
                    className={inputCls}
                    value={row.toGodown}
                    onChange={(e) => updateRow(row.id, { toGodown: e.target.value })}
                    onKeyDown={(e) => handleKeyDown(e, rowIndex, 2)}
                  >
                    {GODOWNS.map((g) => (
                      <option key={g} value={g}>
                        {g}
                      </option>
                    ))}
                  </select>
                </td>
                <td>
                  <input
                    ref={setRef(row.id, 'qty')}
                    type="number"
                    className={`${inputCls} text-right`}
                    value={row.qty || ''}
                    onChange={(e) => updateRow(row.id, { qty: Number(e.target.value) || 0 })}
                    onKeyDown={(e) => handleKeyDown(e, rowIndex, 3)}
                  />
                </td>
                <td>
                  <select
                    ref={setRef(row.id, 'unit')}
                    className={inputCls}
                    value={row.unit}
                    onChange={(e) => updateRow(row.id, { unit: e.target.value })}
                    onKeyDown={(e) => handleKeyDown(e, rowIndex, 4)}
                  >
                    {UNITS.map((u) => (
                      <option key={u} value={u}>
                        {u}
                      </option>
                    ))}
                  </select>
                </td>
                <td>
                  <input
                    ref={setRef(row.id, 'rate')}
                    type="number"
                    className={`${inputCls} text-right`}
                    value={row.rate || ''}
                    onChange={(e) => updateRow(row.id, { rate: Number(e.target.value) || 0 })}
                    onKeyDown={(e) => handleKeyDown(e, rowIndex, 5)}
                  />
                </td>
                <td className="px-2 text-right font-semibold text-slate-800">{formatINR(value)}</td>
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
            );
          })}
        </tbody>
        <tfoot>
          <tr className="bg-slate-50 font-semibold text-slate-700">
            <td className="px-2 py-2 text-right" colSpan={4}>
              Total
            </td>
            <td className="px-2 py-2 text-right">{totals.totalQty}</td>
            <td></td>
            <td></td>
            <td className="px-2 py-2 text-right">{formatINR(totals.totalValue)}</td>
            <td></td>
          </tr>
        </tfoot>
      </table>
      <button
        onClick={() => addRow()}
        className="mt-2 mb-4 flex items-center gap-1 rounded-md border border-dashed border-slate-300 px-3 py-1.5 text-xs font-medium text-slate-500 hover:border-blue-400 hover:text-blue-600"
      >
        + Add Row
      </button>
    </div>
  );
}
