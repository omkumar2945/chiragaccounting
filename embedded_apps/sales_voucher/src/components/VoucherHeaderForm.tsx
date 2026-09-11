import { useState } from 'react';
import type { LedgerGroup, VoucherHeaderData, VoucherType } from '../types';
import { useMasters } from '../context/MastersContext';
import { isAutomaticNumber } from '../store/voucherNumbering';
import { AddressLocationForm } from './AddressLocationForm';

interface Props {
  voucherType: VoucherType;
  data: VoucherHeaderData;
  onChange: (patch: Partial<VoucherHeaderData>) => void;
  uncertainFields?: string[];
  onNotify?: (message: string, kind: 'success' | 'error') => void;
  onAlterLedger?: (id: string) => void;
}

function fieldClass(uncertain: boolean) {
  return `w-full rounded-md border px-2.5 py-1.5 text-sm outline-none transition-colors focus:border-blue-500 focus:ring-2 focus:ring-blue-100 ${
    uncertain ? 'border-amber-400 bg-amber-50 flash-uncertain' : 'border-slate-300 bg-white'
  }`;
}

/** Tally-style default "Under Group" for a party ledger created on the fly from this voucher type. */
const PARTY_GROUP_FOR: Record<VoucherType, 'Sundry Debtors' | 'Sundry Creditors'> = {
  Sales: 'Sundry Debtors',
  'Credit Note': 'Sundry Debtors',
  Purchase: 'Sundry Creditors',
  'Debit Note': 'Sundry Creditors',
  Payment: 'Sundry Creditors',
  Receipt: 'Sundry Debtors',
  Journal: 'Sundry Debtors',
  Contra: 'Sundry Debtors',
  'Stock Journal': 'Sundry Debtors',
  'Manufacturing Journal': 'Sundry Debtors',
};

/** Tally-style default "Under Group" for the Sales/Purchase-type ledger created on the fly. */
const LEDGER_GROUP_FOR: Record<VoucherType, 'Sales Accounts' | 'Purchase Accounts'> = {
  Sales: 'Sales Accounts',
  'Credit Note': 'Sales Accounts',
  Purchase: 'Purchase Accounts',
  'Debit Note': 'Purchase Accounts',
  Payment: 'Purchase Accounts',
  Receipt: 'Sales Accounts',
  Journal: 'Sales Accounts',
  Contra: 'Sales Accounts',
  'Stock Journal': 'Sales Accounts',
  'Manufacturing Journal': 'Sales Accounts',
};

export default function VoucherHeaderForm({ voucherType, data, onChange, uncertainFields = [], onNotify, onAlterLedger }: Props) {
  const { ledgers, addLedger, updateLedger, isDuplicateLedgerName } = useMasters();
  const [useDifferentShippingAddress, setUseDifferentShippingAddress] = useState(false);
  const [partySuggestionsOpen, setPartySuggestionsOpen] = useState(false);
  const [highlightedPartyIndex, setHighlightedPartyIndex] = useState(0);
  const autoNumber = isAutomaticNumber(voucherType, data.voucherDate);
  const isUncertain = (name: string) => uncertainFields.includes(name);
  const label = "block text-[11px] font-semibold uppercase tracking-wide text-slate-500 mb-1";
  const ledgerLabel: Record<VoucherType, string> = {
    Sales: 'Sales Ledger',
    Purchase: 'Purchase Ledger',
    'Debit Note': 'Debit Ledger',
    'Credit Note': 'Credit Ledger',
    Payment: 'Ledger',
    Receipt: 'Ledger',
    Journal: 'Ledger',
    Contra: 'Ledger',
    'Stock Journal': 'Ledger',
    'Manufacturing Journal': 'Ledger',
  };

  function findLedgerByName(name: string) {
    return ledgers.find((l) => l.name.trim().toLowerCase() === name.trim().toLowerCase());
  }

  const partyGroup = PARTY_GROUP_FOR[voucherType];
  const matchingParties = ledgers.filter((ledger) =>
    ledger.group === partyGroup && ledger.name.toLowerCase().includes(data.partyName.trim().toLowerCase())
  );

  function selectParty(name: string) {
    const ledgerMatch = findLedgerByName(name);
    onChange({
      partyName: name,
      ...(ledgerMatch?.gstin ? { partyGSTIN: ledgerMatch.gstin } : {}),
      ...(ledgerMatch?.location ? {
        billingLocation: ledgerMatch.location,
        ...(!useDifferentShippingAddress ? { shippingLocation: ledgerMatch.location } : {}),
        placeOfSupply: ledgerMatch.location.stateName,
      } : {}),
    });
    setPartySuggestionsOpen(false);
  }

  function handlePartyKeyDown(event: React.KeyboardEvent<HTMLInputElement>) {
    if (event.altKey) {
      handleLedgerFieldShortcut(event, data.partyName, partyGroup, data.partyGSTIN);
      return;
    }
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      setPartySuggestionsOpen(true);
      setHighlightedPartyIndex((index) => Math.min(index + 1, matchingParties.length - 1));
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      setPartySuggestionsOpen(true);
      setHighlightedPartyIndex((index) => Math.max(index - 1, 0));
    } else if (event.key === 'Enter' && partySuggestionsOpen && matchingParties[highlightedPartyIndex]) {
      event.preventDefault();
      selectParty(matchingParties[highlightedPartyIndex].name);
    } else if (event.key === 'Escape') {
      setPartySuggestionsOpen(false);
    }
  }

  function handleLedgerFieldShortcut(
    e: React.KeyboardEvent<HTMLInputElement>,
    name: string,
    defaultGroup: LedgerGroup,
    gstin: string
  ) {
    if (e.altKey && e.key.toLowerCase() === 'c') {
      e.preventDefault();
      const trimmed = name.trim();
      if (!trimmed) return;
      if (isDuplicateLedgerName(trimmed)) {
        onNotify?.(`"${trimmed}" already exists. Use Alt+A to alter it.`, 'error');
        return;
      }
      const result = addLedger({
        name: trimmed,
        group: defaultGroup,
        gstin,
        gstRegistrationType: gstin.trim() ? 'Regular' : 'Unregistered/URP',
        openingBalance: 0,
      });
      if (result.ok) {
        onNotify?.(`Ledger "${trimmed}" created under "${defaultGroup}".`, 'success');
      } else {
        onNotify?.(result.error ?? 'Could not create ledger.', 'error');
      }
    } else if (e.altKey && e.key.toLowerCase() === 'a') {
      e.preventDefault();
      const match = findLedgerByName(name);
      if (match && onAlterLedger) {
        onAlterLedger(match.id);
      } else {
        onNotify?.('Type an existing ledger name to alter it.', 'error');
      }
    }
  }

  const isNoteVoucher = voucherType === 'Credit Note' || voucherType === 'Debit Note';

  return (
    <section className="grid grid-cols-4 gap-x-5 gap-y-3 border-b border-slate-200 bg-white px-5 py-4">
      <div>
        <label className={label}>Voucher No.</label>
        <input
          className={fieldClass(isUncertain('voucherNo'))}
          value={data.voucherNo}
          onChange={(e) => onChange({ voucherNo: e.target.value })}
          readOnly={autoNumber}
          title={autoNumber ? 'Auto number is controlled from Masters > Voucher Series.' : 'Manual voucher number enabled in Masters > Voucher Series.'}
        />
      </div>
      <div>
        <label className={label}>Voucher Date</label>
        <input
          type="date"
          className={fieldClass(isUncertain('voucherDate'))}
          value={data.voucherDate}
          onChange={(e) => onChange({ voucherDate: e.target.value })}
        />
      </div>
      <div>
        <label className={label}>{ledgerLabel[voucherType]} (Alt+C create, Alt+A alter)</label>
        <input
          list="ledger-suggestions"
          className={fieldClass(isUncertain('ledger'))}
          value={data.ledger}
          onChange={(e) => onChange({ ledger: e.target.value })}
          onKeyDown={(e) => handleLedgerFieldShortcut(e, data.ledger, LEDGER_GROUP_FOR[voucherType], '')}
          placeholder={voucherType === 'Sales' ? 'Sales A/c - GST 18%' : 'Purchase A/c - GST 18%'}
          title="Alt+C: create if new · Alt+A: alter existing"
        />
        <datalist id="ledger-suggestions">
          {ledgers.map((l) => (
            <option key={l.id} value={l.name} />
          ))}
        </datalist>
      </div>
      <div>
        <label className={label}>Payment Terms</label>
        <input
          className={fieldClass(isUncertain('paymentTerms'))}
          value={data.paymentTerms}
          onChange={(e) => onChange({ paymentTerms: e.target.value })}
          placeholder="Net 30 days"
        />
      </div>

      {isNoteVoucher && (
        <>
          <div>
            <label className={label}>Against Bill</label>
            <input
              className={fieldClass(isUncertain('against'))}
              value={data.against}
              onChange={(e) => onChange({ against: e.target.value })}
              placeholder="Original bill / invoice no."
            />
          </div>
          <div>
            <label className={label}>For What Reason</label>
            <input
              className={fieldClass(isUncertain('reason'))}
              value={data.reason}
              onChange={(e) => onChange({ reason: e.target.value })}
              placeholder="Reason for this debit / credit note"
            />
          </div>
          <div className="col-span-2" />
        </>
      )}

      {!isNoteVoucher && (
        <>
          <div className="col-span-2">
            <label className={label}>Party A/c Name (Alt+C create, Alt+A alter)</label>
            <div className="relative">
              <input
                className={fieldClass(isUncertain('partyName'))}
                value={data.partyName}
                onChange={(e) => {
                  onChange({ partyName: e.target.value });
                  setHighlightedPartyIndex(0);
                  setPartySuggestionsOpen(true);
                }}
                onFocus={() => setPartySuggestionsOpen(true)}
                onBlur={() => window.setTimeout(() => setPartySuggestionsOpen(false), 120)}
                onKeyDown={handlePartyKeyDown}
                placeholder="Select customer... (Alt+C to create)"
                title="Customer/debtor ledgers only. Use Up/Down and Enter to select."
                role="combobox"
                aria-expanded={partySuggestionsOpen}
              />
              {partySuggestionsOpen && matchingParties.length > 0 && (
                <div className="absolute z-30 mt-1 max-h-44 w-full overflow-y-auto rounded-md border border-slate-300 bg-white py-1 shadow-lg">
                  {matchingParties.map((party, index) => (
                    <button
                      key={party.id}
                      type="button"
                      className={`block w-full px-3 py-2 text-left text-sm ${index === highlightedPartyIndex ? 'bg-blue-600 text-white' : 'text-slate-700 hover:bg-slate-100'}`}
                      onMouseDown={(event) => event.preventDefault()}
                      onClick={() => selectParty(party.name)}
                    >
                      {party.name}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
          <div className="col-span-2">
            <label className={label}>Party GSTIN</label>
            <input
              className={fieldClass(isUncertain('partyGSTIN'))}
              value={data.partyGSTIN}
              onChange={(e) => onChange({ partyGSTIN: e.target.value.toUpperCase() })}
              onBlur={(e) => {
                const gstin = e.target.value.trim();
                const match = findLedgerByName(data.partyName);
                if (match && gstin && match.gstin !== gstin) {
                  updateLedger(match.id, {
                    name: match.name,
                    group: match.group,
                    gstin,
                    gstRegistrationType: 'Regular',
                    openingBalance: match.openingBalance,
                    location: match.location,
                  });
                  onNotify?.(`GSTIN linked to ledger "${match.name}".`, 'success');
                }
              }}
              placeholder="29XXXXXXXXXX1Z5"
              maxLength={15}
            />
          </div>
        </>
      )}

      {isNoteVoucher && (
        <>
          <div className="col-span-2">
            <label className={label}>Party A/c Name (Alt+C create, Alt+A alter)</label>
            <div className="relative">
              <input
                className={fieldClass(isUncertain('partyName'))}
                value={data.partyName}
                onChange={(e) => {
                  onChange({ partyName: e.target.value });
                  setHighlightedPartyIndex(0);
                  setPartySuggestionsOpen(true);
                }}
                onFocus={() => setPartySuggestionsOpen(true)}
                onBlur={() => window.setTimeout(() => setPartySuggestionsOpen(false), 120)}
                onKeyDown={handlePartyKeyDown}
                placeholder="Select customer... (Alt+C to create)"
                title="Customer/debtor ledgers only. Use Up/Down and Enter to select."
                role="combobox"
                aria-expanded={partySuggestionsOpen}
              />
              {partySuggestionsOpen && matchingParties.length > 0 && (
                <div className="absolute z-30 mt-1 max-h-44 w-full overflow-y-auto rounded-md border border-slate-300 bg-white py-1 shadow-lg">
                  {matchingParties.map((party, index) => (
                    <button
                      key={party.id}
                      type="button"
                      className={`block w-full px-3 py-2 text-left text-sm ${index === highlightedPartyIndex ? 'bg-blue-600 text-white' : 'text-slate-700 hover:bg-slate-100'}`}
                      onMouseDown={(event) => event.preventDefault()}
                      onClick={() => selectParty(party.name)}
                    >
                      {party.name}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
          <div className="col-span-2">
            <label className={label}>Party GSTIN</label>
            <input
              className={fieldClass(isUncertain('partyGSTIN'))}
              value={data.partyGSTIN}
              onChange={(e) => onChange({ partyGSTIN: e.target.value.toUpperCase() })}
              onBlur={(e) => {
                const gstin = e.target.value.trim();
                const match = findLedgerByName(data.partyName);
                if (match && gstin && match.gstin !== gstin) {
                  updateLedger(match.id, {
                    name: match.name,
                    group: match.group,
                    gstin,
                    gstRegistrationType: 'Regular',
                    openingBalance: match.openingBalance,
                    location: match.location,
                  });
                  onNotify?.(`GSTIN linked to ledger "${match.name}".`, 'success');
                }
              }}
              placeholder="29XXXXXXXXXX1Z5"
              maxLength={15}
            />
          </div>
        </>
      )}

      <div>
        <label className={label}>Invoice No.</label>
        <input
          className={fieldClass(isUncertain('invoiceNo'))}
          value={data.invoiceNo}
          onChange={(e) => onChange({ invoiceNo: e.target.value })}
        />
      </div>
      <div>
        <label className={label}>Invoice Date</label>
        <input
          type="date"
          className={fieldClass(isUncertain('invoiceDate'))}
          value={data.invoiceDate}
          onChange={(e) => onChange({ invoiceDate: e.target.value })}
        />
      </div>
      <div className="col-span-2 self-end pb-2 text-xs text-slate-500">
        Place of Supply: <strong className="text-slate-700">{data.placeOfSupply || 'Select party ledger'}</strong>
      </div>
      <div className="col-span-4 flex items-center justify-between border border-slate-200 bg-slate-50 px-3 py-2">
        <div>
          <p className="text-[11px] font-bold uppercase tracking-wide text-slate-600">Delivery Address</p>
          <p className="text-xs text-slate-500">Billing address is taken automatically from the selected party ledger.</p>
        </div>
        <label className="flex items-center gap-2 text-sm font-medium text-slate-700">
          <input
            type="checkbox"
            checked={useDifferentShippingAddress}
            onChange={(event) => {
              const useDifferentAddress = event.target.checked;
              setUseDifferentShippingAddress(useDifferentAddress);
              if (!useDifferentAddress) onChange({ shippingLocation: data.billingLocation });
            }}
          />
          Deliver to a different address
        </label>
      </div>
      {useDifferentShippingAddress && (
        <AddressLocationForm
          title="Shipping / Delivery Address"
          value={data.shippingLocation}
          onChange={(shippingLocation) => onChange({ shippingLocation })}
        />
      )}
    </section>
  );
}
