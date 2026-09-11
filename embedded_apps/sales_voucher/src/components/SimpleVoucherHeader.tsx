import type { SimpleVoucherHeaderData, VoucherType } from '../types';
import { isAutomaticNumber } from '../store/voucherNumbering';

interface Props {
  data: SimpleVoucherHeaderData;
  onChange: (patch: Partial<SimpleVoucherHeaderData>) => void;
  voucherType: VoucherType;
  referenceLabel?: string;
}

export default function SimpleVoucherHeader({ data, onChange, voucherType, referenceLabel = 'Reference No.' }: Props) {
  const label = 'block text-[11px] font-semibold uppercase tracking-wide text-slate-500 mb-1';
  const fieldClass =
    'w-full rounded-md border border-slate-300 bg-white px-2.5 py-1.5 text-sm outline-none transition-colors focus:border-blue-500 focus:ring-2 focus:ring-blue-100';
  const autoNumber = isAutomaticNumber(voucherType, data.voucherDate);

  return (
    <section className="grid grid-cols-4 gap-x-5 gap-y-3 border-b border-slate-200 bg-white px-5 py-4">
      <div>
        <label className={label}>Voucher No.</label>
        <input className={fieldClass} value={data.voucherNo} onChange={(e) => onChange({ voucherNo: e.target.value })} readOnly={autoNumber} title={autoNumber ? 'Auto number is controlled from Masters > Voucher Series.' : 'Manual voucher number enabled in Masters > Voucher Series.'} />
      </div>
      <div>
        <label className={label}>Voucher Date</label>
        <input
          type="date"
          className={fieldClass}
          value={data.voucherDate}
          onChange={(e) => onChange({ voucherDate: e.target.value })}
        />
      </div>
      <div>
        <label className={label}>{referenceLabel}</label>
        <input className={fieldClass} value={data.referenceNo} onChange={(e) => onChange({ referenceNo: e.target.value })} />
      </div>
      <div className="col-span-1" />
      <div className="col-span-4">
        <label className={label}>Narration</label>
        <input
          className={fieldClass}
          value={data.narration}
          onChange={(e) => onChange({ narration: e.target.value })}
          placeholder="Being..."
        />
      </div>
    </section>
  );
}
