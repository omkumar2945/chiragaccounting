import { useMemo, useState } from 'react';
import type { VoucherRegisterEntry } from '../types';
import { listVouchers } from '../store/voucherRegister';
import { formatINR } from '../utils/calculations';

interface Props {
  onClose: () => void;
}

type RegisterTab = 'voucher' | 'dayBook' | 'ledger';

export default function VoucherRegisters({ onClose }: Props) {
  const [tab, setTab] = useState<RegisterTab>('voucher');
  const [search, setSearch] = useState('');
  const [ledger, setLedger] = useState('');
  const entries = useMemo(() => listVouchers(), []);
  const query = search.trim().toLowerCase();
  const filtered = entries.filter((entry) => {
    const values = [entry.voucherType, entry.voucherNo, entry.invoiceNo, entry.referenceNo, entry.narration, ...(entry.ledgerNames ?? []), ...(entry.stockMovements ?? [])];
    return !query || values.some((value) => value?.toLowerCase().includes(query));
  });
  const ledgerNames = [...new Set(entries.flatMap((entry) => entry.ledgerNames ?? []))].sort();
  const ledgerEntries = ledger ? filtered.filter((entry) => entry.ledgerNames?.includes(ledger)) : filtered;
  const title = tab === 'voucher' ? 'Voucher Register' : tab === 'dayBook' ? 'Day Book' : 'Ledger Register';

  function date(entry: VoucherRegisterEntry) {
    return entry.voucherDate || entry.savedAt.slice(0, 10);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-6">
      <section className="flex h-[80vh] w-full max-w-6xl flex-col overflow-hidden rounded-lg bg-white shadow-2xl">
        <header className="flex items-center justify-between border-b border-slate-200 px-5 py-3">
          <div>
            <h2 className="text-base font-bold text-slate-800">{title}</h2>
            <p className="text-xs text-slate-500">Saved vouchers for this browser and billing profile</p>
          </div>
          <button type="button" onClick={onClose} className="text-xl text-slate-500 hover:text-slate-800" aria-label="Close registers">✕</button>
        </header>
        <div className="flex items-center gap-2 border-b border-slate-200 px-5 py-2">
          {(['voucher', 'dayBook', 'ledger'] as RegisterTab[]).map((name) => (
            <button key={name} type="button" onClick={() => setTab(name)} className={`rounded px-3 py-1.5 text-xs font-semibold ${tab === name ? 'bg-blue-600 text-white' : 'text-slate-600 hover:bg-slate-100'}`}>
              {name === 'voucher' ? 'Voucher Register' : name === 'dayBook' ? 'Day Book' : 'Ledger Register'}
            </button>
          ))}
          <input className="ml-auto w-64 rounded border border-slate-300 px-2 py-1.5 text-xs outline-none focus:border-blue-500" placeholder="Search voucher, party, item..." value={search} onChange={(event) => setSearch(event.target.value)} />
          {tab === 'ledger' && <select className="rounded border border-slate-300 px-2 py-1.5 text-xs" value={ledger} onChange={(event) => setLedger(event.target.value)}><option value="">All ledgers / items</option>{ledgerNames.map((name) => <option key={name}>{name}</option>)}</select>}
        </div>
        <div className="flex-1 overflow-auto">
          {entries.length === 0 ? <p className="p-8 text-center text-sm text-slate-500">No vouchers saved yet.</p> : (
            <table className="w-full text-sm">
              <thead className="sticky top-0 bg-slate-100 text-[11px] font-semibold uppercase text-slate-600"><tr><th className="px-4 py-2 text-left">Date</th><th className="px-4 py-2 text-left">Voucher Type</th><th className="px-4 py-2 text-left">Voucher No.</th><th className="px-4 py-2 text-left">Reference / Invoice</th><th className="px-4 py-2 text-left">Ledger / Item</th><th className="px-4 py-2 text-left">Stock Movement</th><th className="px-4 py-2 text-left">Narration</th><th className="px-4 py-2 text-right">Amount</th></tr></thead>
              <tbody>{(tab === 'ledger' ? ledgerEntries : filtered).map((entry) => <tr key={`${entry.voucherNo}-${entry.savedAt}`} className="border-t border-slate-100 hover:bg-blue-50"><td className="px-4 py-2">{date(entry)}</td><td className="px-4 py-2">{entry.voucherType}</td><td className="px-4 py-2 font-medium">{entry.voucherNo}</td><td className="px-4 py-2">{entry.invoiceNo || entry.referenceNo || '—'}</td><td className="px-4 py-2">{entry.ledgerNames?.join(', ') || '—'}</td><td className="px-4 py-2 text-xs">{entry.stockMovements?.join('; ') || '—'}</td><td className="px-4 py-2">{entry.narration || '—'}</td><td className="px-4 py-2 text-right">{formatINR(entry.totalAmount ?? entry.grandTotal ?? 0)}</td></tr>)}</tbody>
            </table>
          )}
        </div>
      </section>
    </div>
  );
}