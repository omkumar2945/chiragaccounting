import { useRef, useState } from 'react';
import type { EwayTransportData, ItemRow, VoucherHeaderData, VoucherTemplateConfiguration, VoucherType } from '../types';
import VoucherHeaderForm from './VoucherHeaderForm';
import EwayTransportSection from './EwayTransportSection';
import ItemGrid from './ItemGrid';
import TotalsPanel from './TotalsPanel';
import { computeVoucherTotals } from '../utils/calculations';

interface Props {
  voucherType: VoucherType;
  configuration: VoucherTemplateConfiguration;
  header: VoucherHeaderData;
  onHeaderChange: (patch: Partial<VoucherHeaderData>) => void;
  rows: ItemRow[];
  onRowsChange: (rows: ItemRow[]) => void;
  eway: EwayTransportData;
  onEwayChange: (patch: Partial<EwayTransportData>) => void;
  onNotify?: (message: string, kind: 'success' | 'error') => void;
  onAlterItem?: (id: string) => void;
  onAlterLedger?: (id: string) => void;
  onConfirmSave: () => void;
  onSaveAndNew: () => void;
  onPrint: () => void;
  onCancel: () => void;
}

type FileKind = 'image' | 'pdf' | null;

export default function AIInvoiceEntry({
  voucherType,
  configuration,
  header,
  onHeaderChange,
  rows,
  onRowsChange,
  eway,
  onEwayChange,
  onNotify,
  onAlterItem,
  onAlterLedger,
  onConfirmSave,
  onSaveAndNew,
  onPrint,
  onCancel,
}: Props) {
  const [fileUrl, setFileUrl] = useState<string | null>(null);
  const [fileKind, setFileKind] = useState<FileKind>(null);
  const [processing, setProcessing] = useState(false);
  const [extracted, setExtracted] = useState(false);
  const [zoom, setZoom] = useState(1);
  const [rotation, setRotation] = useState(0);
  const [uncertainHeaderFields, setUncertainHeaderFields] = useState<string[]>([]);
  const [uncertainEwayFields, setUncertainEwayFields] = useState<string[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const totals = computeVoucherTotals(rows, header.placeOfSupply);

  function handleFile(file: File) {
    const url = URL.createObjectURL(file);
    setFileUrl(url);
    setFileKind(file.type === 'application/pdf' ? 'pdf' : 'image');
    setExtracted(false);
    setProcessing(true);
    setZoom(1);
    setRotation(0);

    // Simulated OCR/AI extraction pipeline
    setTimeout(() => {
      if (voucherType === 'Purchase') {
        onHeaderChange({
          partyName: 'XYZ SUPPLIERS',
          partyGSTIN: '29AAACX5678K1Z2',
          invoiceNo: 'PUR-7821',
          invoiceDate: new Date().toISOString().slice(0, 10),
          placeOfSupply: 'Karnataka',
        });
        onRowsChange([
          {
            id: 'ai-1',
            itemName: 'Item A',
            hsn: '8517',
            qty: 20,
            unit: 'Nos',
            rate: 450,
            discountPercent: 0,
            gstPercent: 18,
            overridden: false,
          },
          {
            id: 'ai-2',
            itemName: 'Item B',
            hsn: '8517',
            qty: 10,
            unit: 'Nos',
            rate: 700,
            discountPercent: 0,
            gstPercent: 18,
            overridden: false,
            uncertainFields: ['rate'],
          },
        ]);
        setUncertainHeaderFields(['invoiceDate']);
        onEwayChange({
          ewayBillNo: '311007123456',
          ewayBillDate: new Date().toISOString().slice(0, 10),
          transporterName: 'Sri Balaji Transport',
          vehicleNo: 'KA01AB1234',
        });
        setUncertainEwayFields(['vehicleNo']);
      } else {
        onHeaderChange({
          partyName: 'ABC TRADERS',
          partyGSTIN: '29AAACB1234F1Z5',
          invoiceNo: 'INV-4582',
          invoiceDate: new Date().toISOString().slice(0, 10),
          placeOfSupply: 'Karnataka',
        });
        onRowsChange([
          {
            id: 'ai-1',
            itemName: 'Product A',
            hsn: '8471',
            qty: 10,
            unit: 'Nos',
            rate: 500,
            discountPercent: 0,
            gstPercent: 18,
            overridden: false,
          },
          {
            id: 'ai-2',
            itemName: 'Product B',
            hsn: '8473',
            qty: 5,
            unit: 'Nos',
            rate: 800,
            discountPercent: 5,
            gstPercent: 18,
            overridden: false,
            uncertainFields: ['rate'],
          },
        ]);
        setUncertainHeaderFields(['invoiceDate']);
        onEwayChange({
          irn: '3c2d1f9a8b7e6d5c4b3a2918f7e6d5c4b3a29187f6e5d4c3b2a19087e6d5c4b',
          ackNo: '122024001234567',
          ackDate: new Date().toISOString().slice(0, 10),
        });
        setUncertainEwayFields([]);
      }
      setProcessing(false);
      setExtracted(true);
    }, 1400);
  }

  const rowUncertainCount = rows.reduce((n, r) => n + (r.uncertainFields?.length ?? 0), 0);
  const gstinMatched = extracted && header.partyGSTIN.length === 15;

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
    <div className="flex flex-1 overflow-hidden">
      {/* 60% Data Entry */}
      <div className="flex w-[60%] flex-col overflow-hidden border-r border-slate-300">
        <div className="flex items-center justify-between bg-slate-50 px-5 py-2 border-b border-slate-200">
          <h2 className="text-xs font-bold uppercase tracking-wide text-slate-500">Data Entry</h2>
          {processing && (
            <span className="flex items-center gap-1.5 text-xs font-medium text-blue-600">
              <span className="h-2 w-2 animate-ping rounded-full bg-blue-500" />
              Processing invoice with AI…
            </span>
          )}
        </div>
        <div className="flex-1 overflow-auto">
          <VoucherHeaderForm
            voucherType={voucherType}
            data={header}
            onChange={onHeaderChange}
            uncertainFields={uncertainHeaderFields}
            onNotify={onNotify}
            onAlterLedger={onAlterLedger}
          />
          <EwayTransportSection data={eway} onChange={onEwayChange} uncertainFields={uncertainEwayFields} />
          <ItemGrid
            rows={rows}
            onRowsChange={onRowsChange}
            placeOfSupply={header.placeOfSupply}
            onNotify={onNotify}
            onAlterItem={onAlterItem}
            configuration={configuration}
          />
          <TotalsPanel totals={totals} />

          {extracted && (
            <div className="mx-5 mb-4 rounded-md border border-slate-200 bg-slate-50 p-3 text-xs">
              <div className="mb-1 flex items-center gap-1.5 text-emerald-600 font-medium">
                <span>✓</span> AI fetched item, HSN &amp; GST from master
              </div>
              <div className="mb-1 flex items-center gap-1.5 font-medium">
                <span className={gstinMatched ? 'text-emerald-600' : 'text-rose-600'}>
                  {gstinMatched ? '✓' : '✕'}
                </span>
                GSTIN {gstinMatched ? 'matched' : 'could not be verified'}
              </div>
              {rowUncertainCount > 0 && (
                <div className="flex items-center gap-1.5 text-amber-600 font-medium">
                  <span>⚠</span> Rate requires confirmation on {rowUncertainCount} item(s)
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* 40% Original Invoice Preview */}
      <div className="flex w-[40%] flex-col bg-slate-100">
        <div className="flex items-center justify-between bg-slate-50 px-5 py-2 border-b border-slate-200">
          <h2 className="text-xs font-bold uppercase tracking-wide text-slate-500">Original Invoice</h2>
          {fileUrl && (
            <div className="flex items-center gap-1.5">
              <button
                onClick={() => setZoom((z) => Math.min(z + 0.25, 3))}
                className="rounded border border-slate-300 bg-white px-2 py-0.5 text-xs hover:bg-slate-100"
              >
                Zoom +
              </button>
              <button
                onClick={() => setZoom((z) => Math.max(z - 0.25, 0.5))}
                className="rounded border border-slate-300 bg-white px-2 py-0.5 text-xs hover:bg-slate-100"
              >
                Zoom −
              </button>
              <button
                onClick={() => setRotation((r) => (r + 90) % 360)}
                className="rounded border border-slate-300 bg-white px-2 py-0.5 text-xs hover:bg-slate-100"
              >
                Rotate
              </button>
            </div>
          )}
        </div>

        <div className="flex flex-1 flex-col items-center justify-center overflow-auto p-4">
          {!fileUrl && (
            <button
              onClick={() => fileInputRef.current?.click()}
              className="flex h-64 w-full max-w-sm flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-slate-300 bg-white text-slate-400 hover:border-blue-400 hover:text-blue-500"
            >
              <span className="text-3xl">📄</span>
              <span className="text-sm font-medium">Upload or scan invoice</span>
              <span className="text-xs">Image or PDF — click to browse</span>
            </button>
          )}

          {fileUrl && fileKind === 'image' && (
            <div className="flex max-h-full items-center justify-center overflow-auto rounded-md border border-slate-300 bg-white p-2 shadow-sm">
              <img
                src={fileUrl}
                alt="Original invoice preview"
                style={{ transform: `scale(${zoom}) rotate(${rotation}deg)` }}
                className="max-w-full transition-transform"
              />
            </div>
          )}

          {fileUrl && fileKind === 'pdf' && (
            <iframe
              title="Original invoice PDF preview"
              src={fileUrl}
              className="h-[520px] w-full rounded-md border border-slate-300 bg-white shadow-sm"
            />
          )}

          <input
            ref={fileInputRef}
            type="file"
            accept="image/*,application/pdf"
            className="hidden"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) handleFile(f);
            }}
          />

          {fileUrl && (
            <button
              onClick={() => fileInputRef.current?.click()}
              className="mt-3 text-xs font-medium text-blue-600 hover:underline"
            >
              Replace file
            </button>
          )}
        </div>

        {uncertainHeaderFields.length > 0 && (
          <div className="border-t border-slate-200 bg-white px-4 py-3 text-xs">
            {uncertainHeaderFields.map((f) => (
              <div key={f} className="flex items-center gap-1.5 text-amber-600 font-medium">
                <span>⚠</span> Verify: {f === 'invoiceDate' ? 'Invoice Date' : f}
              </div>
            ))}
            {rows
              .filter((r) => r.uncertainFields?.length)
              .map((r) => (
                <div key={r.id} className="flex items-center gap-1.5 text-amber-600 font-medium">
                  <span>⚠</span> Verify: {r.itemName} — {r.uncertainFields?.join(', ')}
                </div>
              ))}
          </div>
        )}
      </div>
      </div>

      <div className="flex items-center justify-end gap-2 border-t border-slate-200 bg-white px-5 py-3">
        <button
          onClick={onCancel}
          className="rounded-md border border-slate-300 px-4 py-1.5 text-sm font-medium text-slate-600 hover:bg-slate-50"
        >
          Cancel
        </button>
        <button
          onClick={onPrint}
          className="rounded-md border border-slate-300 px-4 py-1.5 text-sm font-medium text-slate-600 hover:bg-slate-50"
        >
          Print
        </button>
        <button
          onClick={onSaveAndNew}
          className="rounded-md border border-blue-300 bg-blue-50 px-4 py-1.5 text-sm font-medium text-blue-700 hover:bg-blue-100"
        >
          Save &amp; New
        </button>
        <button
          onClick={onConfirmSave}
          className="rounded-md bg-emerald-600 px-5 py-1.5 text-sm font-semibold text-white shadow-sm hover:bg-emerald-700"
        >
          ✓ Confirm &amp; Save
        </button>
      </div>
    </div>
  );
}
