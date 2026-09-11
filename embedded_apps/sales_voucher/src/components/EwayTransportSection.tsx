import { useState } from 'react';
import type { EwayTransportData } from '../types';

interface Props {
  data: EwayTransportData;
  onChange: (patch: Partial<EwayTransportData>) => void;
  uncertainFields?: string[];
}

const MODES: EwayTransportData['modeOfTransport'][] = ['Road', 'Rail', 'Air', 'Ship'];

function fieldClass(uncertain: boolean) {
  return `w-full rounded-md border px-2.5 py-1.5 text-sm outline-none transition-colors focus:border-blue-500 focus:ring-2 focus:ring-blue-100 ${
    uncertain ? 'border-amber-400 bg-amber-50 flash-uncertain' : 'border-slate-300 bg-white'
  }`;
}

export default function EwayTransportSection({ data, onChange, uncertainFields = [] }: Props) {
  const [expanded, setExpanded] = useState(false);
  const isUncertain = (name: string) => uncertainFields.includes(name);
  const label = 'block text-[11px] font-semibold uppercase tracking-wide text-slate-500 mb-1';
  const filledCount = [data.irn, data.ewayBillNo, data.transporterName, data.vehicleNo].filter(Boolean).length;

  return (
    <section className="border-b border-slate-200 bg-white">
      <button
        onClick={() => setExpanded((e) => !e)}
        className="flex w-full items-center justify-between px-5 py-2 text-left hover:bg-slate-50"
      >
        <span className="flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-slate-600">
          <span className={`inline-block transition-transform ${expanded ? 'rotate-90' : ''}`}>▸</span>
          E-Way Bill / E-Invoice / Transport Details
          {filledCount > 0 && (
            <span className="rounded-full bg-blue-100 px-2 py-0.5 text-[10px] font-semibold text-blue-700">
              {filledCount} filled
            </span>
          )}
        </span>
        <span className="text-[11px] text-slate-400">{expanded ? 'Collapse' : 'Expand'}</span>
      </button>

      {expanded && (
        <div className="grid grid-cols-4 gap-x-5 gap-y-3 border-t border-slate-100 px-5 py-4">
          <div className="col-span-4 text-[11px] font-bold uppercase tracking-wide text-slate-400">
            E-Invoicing
          </div>
          <div>
            <label className={label}>IRN</label>
            <input
              className={fieldClass(isUncertain('irn'))}
              value={data.irn}
              onChange={(e) => onChange({ irn: e.target.value })}
              placeholder="64-char Invoice Reference No."
            />
          </div>
          <div>
            <label className={label}>Ack No.</label>
            <input
              className={fieldClass(isUncertain('ackNo'))}
              value={data.ackNo}
              onChange={(e) => onChange({ ackNo: e.target.value })}
            />
          </div>
          <div>
            <label className={label}>Ack Date</label>
            <input
              type="date"
              className={fieldClass(isUncertain('ackDate'))}
              value={data.ackDate}
              onChange={(e) => onChange({ ackDate: e.target.value })}
            />
          </div>
          <div />

          <div className="col-span-4 mt-1 text-[11px] font-bold uppercase tracking-wide text-slate-400">
            E-Way Bill
          </div>
          <div>
            <label className={label}>E-Way Bill No.</label>
            <input
              className={fieldClass(isUncertain('ewayBillNo'))}
              value={data.ewayBillNo}
              onChange={(e) => onChange({ ewayBillNo: e.target.value })}
              placeholder="12-digit EWB No."
            />
          </div>
          <div>
            <label className={label}>E-Way Bill Date</label>
            <input
              type="date"
              className={fieldClass(isUncertain('ewayBillDate'))}
              value={data.ewayBillDate}
              onChange={(e) => onChange({ ewayBillDate: e.target.value })}
            />
          </div>
          <div>
            <label className={label}>Valid Upto</label>
            <input
              type="date"
              className={fieldClass(isUncertain('ewayValidUpto'))}
              value={data.ewayValidUpto}
              onChange={(e) => onChange({ ewayValidUpto: e.target.value })}
            />
          </div>
          <div />

          <div className="col-span-4 mt-1 text-[11px] font-bold uppercase tracking-wide text-slate-400">
            Transport Details
          </div>
          <div>
            <label className={label}>Transporter Name</label>
            <input
              className={fieldClass(isUncertain('transporterName'))}
              value={data.transporterName}
              onChange={(e) => onChange({ transporterName: e.target.value })}
            />
          </div>
          <div>
            <label className={label}>Transporter ID / GSTIN</label>
            <input
              className={fieldClass(isUncertain('transporterId'))}
              value={data.transporterId}
              onChange={(e) => onChange({ transporterId: e.target.value })}
            />
          </div>
          <div>
            <label className={label}>Vehicle No.</label>
            <input
              className={fieldClass(isUncertain('vehicleNo'))}
              value={data.vehicleNo}
              onChange={(e) => onChange({ vehicleNo: e.target.value.toUpperCase() })}
              placeholder="KA-01-AB-1234"
            />
          </div>
          <div>
            <label className={label}>Mode of Transport</label>
            <select
              className={fieldClass(false)}
              value={data.modeOfTransport}
              onChange={(e) => onChange({ modeOfTransport: e.target.value as EwayTransportData['modeOfTransport'] })}
            >
              {MODES.map((m) => (
                <option key={m} value={m}>
                  {m}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className={label}>Distance (km)</label>
            <input
              type="number"
              className={fieldClass(isUncertain('distanceKm'))}
              value={data.distanceKm || ''}
              onChange={(e) => onChange({ distanceKm: Number(e.target.value) || 0 })}
            />
          </div>
          <div>
            <label className={label}>LR/RR No.</label>
            <input
              className={fieldClass(isUncertain('lrNo'))}
              value={data.lrNo}
              onChange={(e) => onChange({ lrNo: e.target.value })}
            />
          </div>
          <div>
            <label className={label}>LR Date</label>
            <input
              type="date"
              className={fieldClass(isUncertain('lrDate'))}
              value={data.lrDate}
              onChange={(e) => onChange({ lrDate: e.target.value })}
            />
          </div>
          <div>
            <label className={label}>Place of Delivery</label>
            <input
              className={fieldClass(isUncertain('placeOfDelivery'))}
              value={data.placeOfDelivery}
              onChange={(e) => onChange({ placeOfDelivery: e.target.value })}
            />
          </div>
        </div>
      )}
    </section>
  );
}
