import { useRef, useState } from 'react';
import type { ItemRow, VoucherTemplateConfiguration } from '../types';
import { UNITS } from '../data/masters';
import { useMasters } from '../context/MastersContext';
import { computeRowGstSplit, createEmptyRow, formatINR } from '../utils/calculations';
import ConfirmDialog from './ConfirmDialog';

interface Props {
  rows: ItemRow[];
  onRowsChange: (rows: ItemRow[]) => void;
  placeOfSupply: string;
  onNotify?: (message: string, kind: 'success' | 'error') => void;
  onAlterItem?: (id: string) => void;
  configuration?: VoucherTemplateConfiguration;
}

type Col = 'itemName' | 'hsn' | 'qty' | 'unit' | 'rate' | 'discountPercent' | 'gstPercent';
const COLS: Col[] = ['itemName', 'hsn', 'qty', 'unit', 'rate', 'discountPercent', 'gstPercent'];

let idCounter = 1;
const nextId = () => `row-${Date.now()}-${idCounter++}`;

export default function ItemGrid({ rows, onRowsChange, placeOfSupply, onNotify, onAlterItem, configuration }: Props) {
  const { items: itemMasterList, findItemByName, findItemByBarcode, searchItems, addItem } = useMasters();
  const inputRefs = useRef<Record<string, HTMLInputElement | HTMLSelectElement | null>>({});
  const [pendingOverride, setPendingOverride] = useState<{
    rowId: string;
    field: 'hsn' | 'rate' | 'gstPercent';
    value: number | string;
  } | null>(null);

  const setRef = (rowId: string, col: Col) => (el: HTMLInputElement | HTMLSelectElement | null) => {
    inputRefs.current[`${rowId}:${col}`] = el;
  };

  const focusCell = (rowId: string, col: Col) => {
    const el = inputRefs.current[`${rowId}:${col}`];
    el?.focus();
    if (el instanceof HTMLInputElement) el.select();
  };

  function updateRow(rowId: string, patch: Partial<ItemRow>) {
    onRowsChange(rows.map((r) => (r.id === rowId ? { ...r, ...patch } : r)));
  }

  function updateAttribute(row: ItemRow, key: string, value: string) {
    updateRow(row.id, { attributes: { ...row.attributes, [key]: value } });
  }

  function addRow(focusNew = true) {
    const row = createEmptyRow(nextId());
    onRowsChange([...rows, row]);
    if (focusNew) {
      setTimeout(() => focusCell(row.id, 'itemName'), 0);
    }
    return row;
  }

  function removeRow(rowId: string) {
    if (rows.length === 1) {
      onRowsChange([createEmptyRow(nextId())]);
      return;
    }
    onRowsChange(rows.filter((r) => r.id !== rowId));
  }

  function getMatchingItem(value: string) {
    const trimmed = value.trim();
    if (!trimmed) return undefined;
    return findItemByName(trimmed) ?? findItemByBarcode(trimmed);
  }

  function handleItemNameSelect(rowId: string, name: string) {
    const master = getMatchingItem(name);
    if (master) {
      updateRow(rowId, {
        itemName: master.name,
        hsn: master.hsn,
        unit: master.unit,
        rate: master.rate,
        gstPercent: master.gstPercent,
        overridden: false,
      });
    } else {
      updateRow(rowId, { itemName: name });
    }
  }

  function handleOverrideAttempt(row: ItemRow, field: 'hsn' | 'rate' | 'gstPercent', rawValue: string) {
    const master = findItemByName(row.itemName);
    const value = field === 'hsn' ? rawValue : Number(rawValue) || 0;
    if (master) {
      const masterValue = field === 'hsn' ? master.hsn : field === 'rate' ? master.rate : master.gstPercent;
      if (String(masterValue) !== String(value) && rawValue !== '') {
        setPendingOverride({ rowId: row.id, field, value });
        return;
      }
    }
    updateRow(row.id, { [field]: value } as Partial<ItemRow>);
  }

  function confirmOverride() {
    if (!pendingOverride) return;
    updateRow(pendingOverride.rowId, { [pendingOverride.field]: pendingOverride.value, overridden: true } as Partial<ItemRow>);
    setPendingOverride(null);
  }

  function cancelOverride() {
    setPendingOverride(null);
  }

  function moveToNext(rowIndex: number, colIndex: number) {
    const isLastCol = colIndex === COLS.length - 1;
    if (!isLastCol) {
      focusCell(rows[rowIndex].id, COLS[colIndex + 1]);
      return;
    }
    const isLastRow = rowIndex === rows.length - 1;
    if (isLastRow) {
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

  function handleBarcodeScan(rowId: string) {
    const scanned = window.prompt('Scan or enter item barcode', '');
    if (!scanned) return;
    const matched = getMatchingItem(scanned);
    if (matched) {
      handleItemNameSelect(rowId, matched.name);
      setTimeout(() => focusCell(rowId, 'qty'), 0);
      return;
    }
    onNotify?.(`No item found for barcode "${scanned}".`, 'error');
  }

  function handleItemNameKeyDown(e: React.KeyboardEvent, row: ItemRow, rowIndex: number) {
    if (e.altKey && e.key.toLowerCase() === 'c') {
      e.preventDefault();
      const name = row.itemName.trim();
      if (!name) return;
      if (findItemByName(name)) {
        onNotify?.(`"${name}" already exists. Use Alt+A to alter it.`, 'error');
        return;
      }
      const result = addItem({ name, barcode: '', hsn: row.hsn, unit: row.unit, rate: row.rate, gstPercent: row.gstPercent, category: '', stockQty: 0 });
      if (result.ok) {
        updateRow(row.id, { overridden: false });
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

  const inputCls =
    'w-full rounded border-none bg-transparent px-1.5 py-1 text-[12px] outline-none focus:bg-blue-50 focus:ring-1 focus:ring-blue-400';

  const dynamicFields = configuration?.dynamicFields ?? [];
  const units = [...new Set([...UNITS, ...(configuration?.units ?? [])])];
  const hsnSuggestions = [...new Set([
    ...itemMasterList.map((item) => item.hsn).filter(Boolean),
    ...(configuration?.taxSuggestions.map((suggestion) => suggestion.code) ?? []),
  ])];
  const rateSuggestions = [...new Set(itemMasterList.map((item) => item.rate.toString()))];
  const gstSuggestions = [...new Set([
    ...itemMasterList.map((item) => item.gstPercent.toString()),
    ...(configuration?.taxSuggestions.map((suggestion) => suggestion.gstRate.toString()) ?? []),
  ])];

  return (
    <div className="min-h-[220px] flex-none overflow-auto px-3 pt-3">
      {pendingOverride && (
        <ConfirmDialog
          title="Override Master Value?"
          message="This value differs from the item master. Do you want to manually override it for this voucher only?"
          confirmLabel="Override"
          onConfirm={confirmOverride}
          onCancel={cancelOverride}
        />
      )}
      <table
        className="voucher-table table-fixed text-xs"
        style={{ minWidth: `${1120 + dynamicFields.length * 120}px` }}
      >
        <colgroup>
          <col className="w-10" />
          <col className="w-[230px]" />
          {dynamicFields.map((field) => <col key={field.key} className="w-[120px]" />)}
          <col className="w-20" />
          <col className="w-16" />
          <col className="w-16" />
          <col className="w-20" />
          <col className="w-16" />
          <col className="w-24" />
          <col className="w-16" />
          <col className="w-20" />
          <col className="w-20" />
          <col className="w-20" />
          <col className="w-24" />
          <col className="w-8" />
        </colgroup>
        <thead>
          <tr className="bg-slate-100 text-[10px] font-semibold uppercase text-slate-600">
            <th className="sticky left-0 z-20 bg-slate-100 px-1.5 py-1.5">S.No</th>
            <th className="sticky left-10 z-20 bg-slate-100 px-1.5 py-1.5 text-left">Item / Description</th>
            {dynamicFields.map((field) => (
              <th key={field.key} className="px-1.5 py-1.5">{field.label}</th>
            ))}
            <th className="px-1.5 py-1.5">HSN</th>
            <th className="px-1.5 py-1.5">Qty</th>
            <th className="px-1.5 py-1.5">Unit</th>
            <th className="px-1.5 py-1.5">Rate</th>
            <th className="px-1.5 py-1.5">Disc</th>
            <th className="px-1.5 py-1.5">Taxable</th>
            <th className="px-1.5 py-1.5">GST</th>
            <th className="px-1.5 py-1.5">CGST</th>
            <th className="px-1.5 py-1.5">SGST</th>
            <th className="px-1.5 py-1.5">IGST</th>
            <th className="px-1.5 py-1.5">Total</th>
            <th className="px-1 py-1.5"></th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => {
            const totals = computeRowGstSplit(row, placeOfSupply);
            const suggestions = searchItems(row.itemName);
            const uncertain = row.uncertainFields ?? [];
            return (
              <tr key={row.id} className="bg-white hover:bg-slate-50">
                <td className="sticky left-0 z-10 bg-white text-center text-slate-500">{rowIndex + 1}</td>
                <td className="sticky left-10 z-10 bg-white">
                  <div className="flex items-center gap-1">
                    <input
                      ref={setRef(row.id, 'itemName')}
                      className={`${inputCls} ${uncertain.includes('itemName') ? 'bg-amber-50 flash-uncertain' : ''}`}
                      value={row.itemName}
                      list={`item-master-${row.id}`}
                      onChange={(e) => handleItemNameSelect(row.id, e.target.value)}
                      onKeyDown={(e) => handleItemNameKeyDown(e, row, rowIndex)}
                      placeholder="Scan barcode or type item name..."
                      title="Alt+C: create if new · Alt+A: alter existing"
                    />
                    <button
                      type="button"
                      onClick={() => handleBarcodeScan(row.id)}
                      className="shrink-0 rounded border border-slate-300 px-1.5 py-1 text-[10px] font-semibold uppercase text-slate-600 hover:border-blue-400 hover:text-blue-600"
                      title="Scan item barcode"
                    >
                      Scan
                    </button>
                  </div>
                  <datalist id={`item-master-${row.id}`}>
                    {(suggestions.length ? suggestions : itemMasterList).map((m) => (
                      <option key={m.id} value={m.name} />
                    ))}
                  </datalist>
                </td>
                {dynamicFields.map((field) => (
                  <td key={field.key}>
                    <input
                      type={field.inputType}
                      className={inputCls}
                      value={row.attributes?.[field.key] ?? ''}
                      onChange={(event) => updateAttribute(row, field.key, event.target.value)}
                      aria-label={field.label}
                    />
                  </td>
                ))}
                <td>
                  <input
                    ref={setRef(row.id, 'hsn')}
                    className={`${inputCls} text-center ${row.overridden ? 'text-amber-700 font-medium' : ''}`}
                    value={row.hsn}
                    list={`hsn-suggestions-${row.id}`}
                    onChange={(e) => handleOverrideAttempt(row, 'hsn', e.target.value)}
                    onKeyDown={(e) => handleKeyDown(e, rowIndex, 1)}
                  />
                  <datalist id={`hsn-suggestions-${row.id}`}>
                    {hsnSuggestions.map((value) => (
                      <option key={value} value={value} />
                    ))}
                  </datalist>
                </td>
                <td>
                  <input
                    ref={setRef(row.id, 'qty')}
                    type="number"
                    className={`${inputCls} text-right`}
                    value={row.qty || ''}
                    onChange={(e) => updateRow(row.id, { qty: Number(e.target.value) || 0 })}
                    onKeyDown={(e) => handleKeyDown(e, rowIndex, 2)}
                  />
                </td>
                <td>
                  <select
                    ref={setRef(row.id, 'unit')}
                    className={inputCls}
                    value={row.unit}
                    onChange={(e) => updateRow(row.id, { unit: e.target.value })}
                    onKeyDown={(e) => handleKeyDown(e, rowIndex, 3)}
                  >
                    {units.map((u) => (
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
                    className={`${inputCls} text-right ${row.overridden ? 'text-amber-700 font-medium' : ''}`}
                    value={row.rate || ''}
                    list={`rate-suggestions-${row.id}`}
                    onChange={(e) => handleOverrideAttempt(row, 'rate', e.target.value)}
                    onKeyDown={(e) => handleKeyDown(e, rowIndex, 4)}
                  />
                  <datalist id={`rate-suggestions-${row.id}`}>
                    {rateSuggestions.map((value) => (
                      <option key={value} value={value} />
                    ))}
                  </datalist>
                </td>
                <td>
                  <input
                    ref={setRef(row.id, 'discountPercent')}
                    type="number"
                    className={`${inputCls} text-right`}
                    value={row.discountPercent || ''}
                    onChange={(e) => updateRow(row.id, { discountPercent: Number(e.target.value) || 0 })}
                    onKeyDown={(e) => handleKeyDown(e, rowIndex, 5)}
                  />
                </td>
                <td className="px-2 text-right font-medium text-slate-700">{formatINR(totals.taxableValue)}</td>
                <td>
                  <input
                    ref={setRef(row.id, 'gstPercent')}
                    type="number"
                    className={`${inputCls} text-right ${row.overridden ? 'text-amber-700 font-medium' : ''}`}
                    value={row.gstPercent || ''}
                    list={`gst-suggestions-${row.id}`}
                    onChange={(e) => handleOverrideAttempt(row, 'gstPercent', e.target.value)}
                    onKeyDown={(e) => handleKeyDown(e, rowIndex, 6)}
                  />
                  <datalist id={`gst-suggestions-${row.id}`}>
                    {gstSuggestions.map((value) => (
                      <option key={value} value={value} />
                    ))}
                  </datalist>
                </td>
                <td className="px-2 text-right text-slate-600">{totals.cgst ? formatINR(totals.cgst) : '—'}</td>
                <td className="px-2 text-right text-slate-600">{totals.sgst ? formatINR(totals.sgst) : '—'}</td>
                <td className="px-2 text-right text-slate-600">{totals.igst ? formatINR(totals.igst) : '—'}</td>
                <td className="px-2 text-right font-semibold text-slate-800">{formatINR(totals.total)}</td>
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
