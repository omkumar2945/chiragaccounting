import type { VoucherTotals } from '../types';
import { formatINR } from '../utils/calculations';
import { amountInWords } from '../utils/numberToWords';

interface Props {
  totals: VoucherTotals;
}

export default function TotalsPanel({ totals }: Props) {
  return (
    <section className="border-t border-slate-200 bg-white px-5 py-4">
      <div className="flex justify-end">
        <div className="w-80 space-y-1.5 text-sm">
          <Row label="Taxable Amount" value={totals.taxableAmount} />
          <Row label="CGST" value={totals.cgst} />
          <Row label="SGST" value={totals.sgst} />
          <Row label="IGST" value={totals.igst} />
          <Row label="Round Off" value={totals.roundOff} />
          <div className="my-1 border-t border-slate-300" />
          <div className="flex items-center justify-between rounded-md bg-blue-50 px-3 py-2">
            <span className="text-sm font-bold text-slate-800">GRAND TOTAL</span>
            <span className="text-base font-bold text-blue-700">₹ {formatINR(totals.grandTotal)}</span>
          </div>
        </div>
      </div>
      <div className="mt-3 rounded-md border border-slate-200 bg-slate-50 px-3 py-2 text-xs text-slate-600">
        <span className="font-semibold text-slate-700">Amount in Words: </span>
        {amountInWords(totals.grandTotal)}
      </div>
    </section>
  );
}

function Row({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex items-center justify-between px-3 text-slate-600">
      <span>{label}</span>
      <span className="font-medium text-slate-800">₹ {formatINR(value)}</span>
    </div>
  );
}
