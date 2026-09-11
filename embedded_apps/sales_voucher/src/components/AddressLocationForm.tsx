import { useState } from 'react';
import type { StandardAddress } from '../types';
import { INDIAN_STATES } from '../data/masters';

interface Props {
  title: string;
  value: StandardAddress;
  onChange: (value: StandardAddress) => void;
  sameAs?: StandardAddress;
}

const inputClass = 'w-full rounded-md border border-slate-300 bg-white px-2.5 py-1.5 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100';
const labelClass = 'block text-[11px] font-semibold uppercase tracking-wide text-slate-500 mb-1';

export function emptyAddress(): StandardAddress {
  return {
    addressLine1: '', addressLine2: '', countryId: 'IN', countryName: 'India',
    stateId: '', stateName: '', cityId: '', cityName: '', district: '', pincode: '',
    locality: '', postOffice: '', source: 'manual',
  };
}

export function AddressLocationForm({ title, value, onChange, sameAs }: Props) {
  const [sameAsChecked, setSameAsChecked] = useState(false);
  const [lookupStatus, setLookupStatus] = useState('');
  const patch = (change: Partial<StandardAddress>) => onChange({ ...value, ...change, source: 'manual' });

  async function lookupPincode(pincode: string) {
    patch({ pincode });
    if (!/^\d{6}$/.test(pincode)) return;
    setLookupStatus('Finding location...');
    try {
      const baseUrl = (import.meta.env.VITE_LOCATION_API_BASE_URL as string | undefined)?.replace(/\/$/, '') ?? '';
      const response = await fetch(`${baseUrl}/api/locations/pincode/${pincode}`);
      const body = await response.json() as { locations?: StandardAddress[] };
      const match = body.locations?.[0];
      if (!response.ok || !match) throw new Error('No location');
      onChange({ ...value, ...match, addressLine1: value.addressLine1, addressLine2: value.addressLine2, pincode });
      setLookupStatus('Location filled from pincode. You can edit any field.');
    } catch {
      setLookupStatus('Location lookup unavailable. Enter the fields manually.');
    }
  }

  return (
    <fieldset className="col-span-4 border border-slate-200 bg-slate-50 p-3">
      <div className="mb-3 flex items-center justify-between">
        <legend className="text-[11px] font-bold uppercase tracking-wide text-slate-600">{title}</legend>
        {sameAs && (
          <label className="flex items-center gap-2 text-xs text-slate-600">
            <input type="checkbox" checked={sameAsChecked} onChange={(event) => {
              const checked = event.target.checked;
              setSameAsChecked(checked);
              if (checked) onChange({ ...sameAs });
            }} />
            Same as Billing Address
          </label>
        )}
      </div>
      <div className="grid grid-cols-4 gap-3">
        <div className="col-span-2"><label className={labelClass}>Address Line 1</label><input className={inputClass} value={value.addressLine1} onChange={(e) => patch({ addressLine1: e.target.value })} /></div>
        <div className="col-span-2"><label className={labelClass}>Address Line 2</label><input className={inputClass} value={value.addressLine2} onChange={(e) => patch({ addressLine2: e.target.value })} /></div>
        <div><label className={labelClass}>Pincode</label><input className={inputClass} inputMode="numeric" maxLength={6} value={value.pincode} onChange={(e) => void lookupPincode(e.target.value.replace(/\D/g, '').slice(0, 6))} /></div>
        <div><label className={labelClass}>Locality</label><input className={inputClass} value={value.locality} onChange={(e) => patch({ locality: e.target.value })} /></div>
        <div><label className={labelClass}>City</label><input className={inputClass} value={value.cityName} onChange={(e) => patch({ cityName: e.target.value, cityId: '' })} /></div>
        <div><label className={labelClass}>District</label><input className={inputClass} value={value.district} onChange={(e) => patch({ district: e.target.value })} /></div>
        <div><label className={labelClass}>State / UT</label><input className={inputClass} list="indian-state-options" value={value.stateName} onChange={(e) => patch({ stateName: e.target.value, stateId: '' })} /><datalist id="indian-state-options">{INDIAN_STATES.map((state) => <option key={state} value={state} />)}</datalist></div>
        <div><label className={labelClass}>Country</label><input className={inputClass} value={value.countryName} onChange={(e) => patch({ countryName: e.target.value, countryId: e.target.value.toLowerCase() === 'india' ? 'IN' : '' })} /></div>
        <div className="col-span-2 self-end pb-1 text-xs text-slate-500">{lookupStatus}</div>
      </div>
    </fieldset>
  );
}