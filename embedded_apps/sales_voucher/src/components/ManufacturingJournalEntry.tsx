import type { ManufacturingMaterialRow, ManufacturingOutput, SimpleVoucherHeaderData } from '../types';
import { GODOWNS, UNITS } from '../data/masters';
import { useMasters } from '../context/MastersContext';
import { formatINR } from '../utils/calculations';

interface Props {
  header: SimpleVoucherHeaderData;
  output: ManufacturingOutput;
  materials: ManufacturingMaterialRow[];
  onHeaderChange: (patch: Partial<SimpleVoucherHeaderData>) => void;
  onOutputChange: (patch: Partial<ManufacturingOutput>) => void;
  onMaterialsChange: (rows: ManufacturingMaterialRow[]) => void;
}

let materialCounter = 1;

function emptyMaterial(): ManufacturingMaterialRow {
  return {
    id: `material-${Date.now()}-${materialCounter++}`,
    itemName: '',
    unit: 'Nos',
    godown: 'Main Godown',
    qty: 0,
    rate: 0,
  };
}

export default function ManufacturingJournalEntry({
  header,
  output,
  materials,
  onHeaderChange,
  onOutputChange,
  onMaterialsChange,
}: Props) {
  const { items, findItemByName, searchItems } = useMasters();
  const materialValue = materials.reduce((sum, row) => sum + row.qty * row.rate, 0);
  const outputValue = output.qty * output.rate;
  const label = 'block text-[11px] font-semibold uppercase tracking-wide text-slate-500 mb-1';
  const inputClass =
    'w-full rounded-md border border-slate-300 bg-white px-2.5 py-1.5 text-sm outline-none transition-colors focus:border-blue-500 focus:ring-2 focus:ring-blue-100';

  function updateMaterial(id: string, patch: Partial<ManufacturingMaterialRow>) {
    onMaterialsChange(materials.map((row) => (row.id === id ? { ...row, ...patch } : row)));
  }

  function selectMaterial(id: string, itemName: string) {
    const item = findItemByName(itemName);
    updateMaterial(id, item ? { itemName, unit: item.unit, rate: item.rate } : { itemName });
  }

  function selectOutput(itemName: string) {
    const item = findItemByName(itemName);
    onOutputChange(item ? { itemName, unit: item.unit, rate: item.rate } : { itemName });
  }

  function removeMaterial(id: string) {
    const remaining = materials.filter((row) => row.id !== id);
    onMaterialsChange(remaining.length ? remaining : [emptyMaterial()]);
  }

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <section className="grid grid-cols-4 gap-x-5 gap-y-3 border-b border-slate-200 bg-white px-5 py-4">
        <div>
          <label className={label}>Voucher No.</label>
          <input className={inputClass} value={header.voucherNo} onChange={(e) => onHeaderChange({ voucherNo: e.target.value })} />
        </div>
        <div>
          <label className={label}>Production Date</label>
          <input type="date" className={inputClass} value={header.voucherDate} onChange={(e) => onHeaderChange({ voucherDate: e.target.value })} />
        </div>
        <div>
          <label className={label}>BOQ / Batch No.</label>
          <input className={inputClass} value={header.referenceNo} onChange={(e) => onHeaderChange({ referenceNo: e.target.value })} placeholder="BOQ-001" />
        </div>
        <div className="col-span-1" />
        <div className="col-span-4">
          <label className={label}>Narration</label>
          <input className={inputClass} value={header.narration} onChange={(e) => onHeaderChange({ narration: e.target.value })} placeholder="Raw material issued for production" />
        </div>
      </section>

      <div className="flex-1 overflow-auto px-5 py-4">
        <section className="border border-emerald-200 bg-emerald-50">
          <div className="flex items-center justify-between border-b border-emerald-200 px-3 py-2">
            <h2 className="text-xs font-bold uppercase text-emerald-800">Finished Goods Inward</h2>
            <span className="text-xs font-semibold text-emerald-700">Inward Value: {formatINR(outputValue)}</span>
          </div>
          <div className="grid grid-cols-[minmax(220px,1fr)_120px_110px_100px_120px] gap-3 p-3">
            <input className={inputClass} value={output.itemName} list="manufacturing-output-items" onChange={(e) => selectOutput(e.target.value)} placeholder="Finished good item..." />
            <input type="number" className={inputClass} value={output.qty || ''} onChange={(e) => onOutputChange({ qty: Number(e.target.value) || 0 })} placeholder="Qty" />
            <select className={inputClass} value={output.unit} onChange={(e) => onOutputChange({ unit: e.target.value })}>{UNITS.map((unit) => <option key={unit}>{unit}</option>)}</select>
            <select className={inputClass} value={output.godown} onChange={(e) => onOutputChange({ godown: e.target.value })}>{GODOWNS.map((godown) => <option key={godown}>{godown}</option>)}</select>
            <input type="number" className={inputClass} value={output.rate || ''} onChange={(e) => onOutputChange({ rate: Number(e.target.value) || 0 })} placeholder="Rate" />
          </div>
          <datalist id="manufacturing-output-items">{items.map((item) => <option key={item.id} value={item.name} />)}</datalist>
        </section>

        <section className="mt-4 border border-rose-200 bg-white">
          <div className="flex items-center justify-between border-b border-rose-200 bg-rose-50 px-3 py-2">
            <h2 className="text-xs font-bold uppercase text-rose-800">BOQ - Raw Material Consumption (Outward)</h2>
            <div className="flex items-center gap-3">
              <span className="text-xs font-semibold text-rose-700">Material Cost: {formatINR(materialValue)}</span>
              <button type="button" onClick={() => onOutputChange({ rate: output.qty ? materialValue / output.qty : materialValue })} className="rounded border border-emerald-600 bg-white px-2 py-1 text-xs font-semibold text-emerald-700 hover:bg-emerald-50">Use as FG Cost</button>
            </div>
          </div>
          <table className="w-full text-sm">
            <thead className="bg-slate-100 text-[11px] font-semibold uppercase text-slate-600">
              <tr><th className="px-3 py-2 text-left">Raw Material</th><th className="px-3 py-2">Godown</th><th className="px-3 py-2">Qty</th><th className="px-3 py-2">Unit</th><th className="px-3 py-2">Rate</th><th className="px-3 py-2 text-right">Value</th><th /></tr>
            </thead>
            <tbody>
              {materials.map((row) => {
                const suggestions = searchItems(row.itemName);
                return <tr key={row.id} className="border-t border-slate-100">
                  <td className="px-3 py-2"><input className={inputClass} value={row.itemName} list={`manufacturing-material-${row.id}`} onChange={(e) => selectMaterial(row.id, e.target.value)} placeholder="Raw material..." /><datalist id={`manufacturing-material-${row.id}`}>{(suggestions.length ? suggestions : items).map((item) => <option key={item.id} value={item.name} />)}</datalist></td>
                  <td className="px-3 py-2"><select className={inputClass} value={row.godown} onChange={(e) => updateMaterial(row.id, { godown: e.target.value })}>{GODOWNS.map((godown) => <option key={godown}>{godown}</option>)}</select></td>
                  <td className="px-3 py-2"><input type="number" className={inputClass} value={row.qty || ''} onChange={(e) => updateMaterial(row.id, { qty: Number(e.target.value) || 0 })} /></td>
                  <td className="px-3 py-2"><select className={inputClass} value={row.unit} onChange={(e) => updateMaterial(row.id, { unit: e.target.value })}>{UNITS.map((unit) => <option key={unit}>{unit}</option>)}</select></td>
                  <td className="px-3 py-2"><input type="number" className={inputClass} value={row.rate || ''} onChange={(e) => updateMaterial(row.id, { rate: Number(e.target.value) || 0 })} /></td>
                  <td className="px-3 py-2 text-right font-semibold text-slate-800">{formatINR(row.qty * row.rate)}</td>
                  <td className="px-1 py-2 text-center"><button type="button" onClick={() => removeMaterial(row.id)} className="text-slate-400 hover:text-rose-600" aria-label="Remove raw material">✕</button></td>
                </tr>;
              })}
            </tbody>
          </table>
          <button type="button" onClick={() => onMaterialsChange([...materials, emptyMaterial()])} className="m-3 rounded border border-dashed border-rose-300 px-3 py-1.5 text-xs font-semibold text-rose-700 hover:border-rose-500">+ Add Raw Material</button>
        </section>
      </div>
    </div>
  );
}