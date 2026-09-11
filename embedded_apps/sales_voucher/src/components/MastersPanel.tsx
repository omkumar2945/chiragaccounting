import { useEffect, useRef, useState } from 'react';
import type { ItemMasterEntry, LedgerMasterEntry } from '../types';
import { GST_REGISTRATION_TYPES, LEDGER_GROUPS } from '../types';
import { isGstLedgerName, useMasters } from '../context/MastersContext';
import VoucherNumberingPanel from './VoucherNumberingPanel';
import { AddressLocationForm, emptyAddress } from './AddressLocationForm';

interface Props {
  onClose: () => void;
  initialTab?: 'items' | 'ledgers';
  initialItemId?: string;
  initialLedgerId?: string;
}

type Tab = 'items' | 'ledgers' | 'units' | 'categories' | 'voucherSeries';

const emptyItemForm = { name: '', barcode: '', hsn: '', unit: 'Nos', rate: 0, gstPercent: 18, category: '', stockQty: 0 };
const emptyLedgerForm = {
  name: '',
  group: LEDGER_GROUPS[0],
  gstin: '',
  gstRegistrationType: GST_REGISTRATION_TYPES[0],
  openingBalance: 0,
  location: emptyAddress(),
  contactName: '',
  mobile: '',
  email: '',
};

type GstLookupResponse = {
  type: 'gstin-validation-result';
  requestId: string;
  profile?: {
    gstin: string;
    legalName: string;
    tradeName: string;
    address: string;
    state: string;
    pincode: string;
    email: string;
    mobile: string;
  };
  message: string;
};

const TAB_LABEL: Record<Tab, string> = {
  items: 'Items',
  ledgers: 'Ledgers',
  units: 'Units',
  categories: 'Categories',
  voucherSeries: 'Voucher Series',
};

export default function MastersPanel({ onClose, initialTab, initialItemId, initialLedgerId }: Props) {
  const {
    items,
    ledgers,
    units,
    categories,
    addItem,
    updateItem,
    addLedger,
    updateLedger,
    isDuplicateItemName,
    isDuplicateLedgerName,
    addUnit,
    isDuplicateUnitName,
    addCategory,
    isDuplicateCategoryName,
  } = useMasters();
  const [tab, setTab] = useState<Tab>(initialTab ?? 'items');
  const [search, setSearch] = useState('');
  const [editingItemId, setEditingItemId] = useState<string | null>(null);
  const [editingLedgerId, setEditingLedgerId] = useState<string | null>(null);
  const [itemForm, setItemForm] = useState(emptyItemForm);
  const [ledgerForm, setLedgerForm] = useState<{
    name: string;
    group: string;
    gstin: string;
    gstRegistrationType: string;
    openingBalance: number;
    location: ReturnType<typeof emptyAddress>;
    contactName: string;
    mobile: string;
    email: string;
  }>(emptyLedgerForm);
  const [unitName, setUnitName] = useState('');
  const [categoryName, setCategoryName] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [isFetchingGst, setIsFetchingGst] = useState(false);
  const gstRequestId = useRef<string | null>(null);

  useEffect(() => {
    function handleGstinValidation(event: MessageEvent<GstLookupResponse>) {
      const data = event.data;
      if (data?.type !== 'gstin-validation-result' || data.requestId !== gstRequestId.current) return;
      gstRequestId.current = null;
      setIsFetchingGst(false);
      if (!data.profile) {
        setError(data.message);
        return;
      }
      const profile = data.profile;
      setLedgerForm((form) => ({
        ...form,
        gstin: profile.gstin,
        gstRegistrationType: 'Regular',
        name: form.name.trim() || profile.tradeName || profile.legalName,
        contactName: form.contactName.trim() || profile.legalName || profile.tradeName,
        mobile: form.mobile.trim() || profile.mobile,
        email: form.email.trim() || profile.email,
        location: {
          ...form.location,
          addressLine1: form.location.addressLine1.trim() || profile.address,
          stateName: form.location.stateName.trim() || profile.state,
          pincode: form.location.pincode.trim() || profile.pincode,
          source: 'gstin-validation',
        },
      }));
      setError(null);
      setSuccess(data.message);
    }

    window.addEventListener('message', handleGstinValidation);
    return () => window.removeEventListener('message', handleGstinValidation);
  }, []);

  useEffect(() => {
    if (initialItemId) {
      const item = items.find((i) => i.id === initialItemId);
      if (item) {
        setTab('items');
        setEditingItemId(item.id);
        setItemForm({
          name: item.name,
          barcode: item.barcode ?? '',
          hsn: item.hsn,
          unit: item.unit,
          rate: item.rate,
          gstPercent: item.gstPercent,
          category: item.category ?? '',
          stockQty: item.stockQty ?? 0,
        });
      }
    } else if (initialLedgerId) {
      const ledger = ledgers.find((l) => l.id === initialLedgerId);
      if (ledger) {
        setTab('ledgers');
        setEditingLedgerId(ledger.id);
        setLedgerForm({
          name: ledger.name,
          group: ledger.group,
          gstin: ledger.gstin,
          gstRegistrationType: ledger.gstRegistrationType,
          openingBalance: ledger.openingBalance,
          location: ledger.location ?? emptyAddress(),
          contactName: ledger.contactName ?? '',
          mobile: ledger.mobile ?? '',
          email: ledger.email ?? '',
        });
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [initialItemId, initialLedgerId]);

  const filteredItems = items.filter((i) => i.name.toLowerCase().includes(search.trim().toLowerCase()));
  const filteredLedgers = ledgers.filter((l) => l.name.toLowerCase().includes(search.trim().toLowerCase()));
  const filteredUnits = units.filter((u) => u.name.toLowerCase().includes(search.trim().toLowerCase()));
  const filteredCategories = categories.filter((c) => c.name.toLowerCase().includes(search.trim().toLowerCase()));

  function switchTab(t: Tab) {
    setTab(t);
    setSearch('');
    setError(null);
    setSuccess(null);
  }

  function startNewItem() {
    setEditingItemId(null);
    setItemForm(emptyItemForm);
    setError(null);
    setSuccess(null);
  }

  function startEditItem(item: ItemMasterEntry) {
    setEditingItemId(item.id);
    setItemForm({
      name: item.name,
      barcode: item.barcode ?? '',
      hsn: item.hsn,
      unit: item.unit,
      rate: item.rate,
      gstPercent: item.gstPercent,
      category: item.category ?? '',
      stockQty: item.stockQty ?? 0,
    });
    setError(null);
    setSuccess(null);
  }

  function saveItem() {
    const result = editingItemId ? updateItem(editingItemId, itemForm) : addItem(itemForm);
    if (!result.ok) {
      setError(result.error ?? 'Could not save item.');
      setSuccess(null);
      return;
    }
    setError(null);
    setSuccess(editingItemId ? `"${itemForm.name}" updated.` : `"${itemForm.name}" created.`);
    startNewItem();
  }

  function startNewLedger() {
    setEditingLedgerId(null);
    setLedgerForm(emptyLedgerForm);
    setError(null);
    setSuccess(null);
  }

  function startEditLedger(ledger: LedgerMasterEntry) {
    setEditingLedgerId(ledger.id);
    setLedgerForm({
      name: ledger.name,
      group: ledger.group,
      gstin: ledger.gstin,
      gstRegistrationType: ledger.gstRegistrationType,
      openingBalance: ledger.openingBalance,
      location: ledger.location ?? emptyAddress(),
      contactName: ledger.contactName ?? '',
      mobile: ledger.mobile ?? '',
      email: ledger.email ?? '',
    });
    setError(null);
    setSuccess(null);
  }

  function saveLedger() {
    const requiresPartyAddress = ledgerForm.group === 'Sundry Debtors' || ledgerForm.group === 'Sundry Creditors';
    if (requiresPartyAddress && !ledgerForm.location.addressLine1.trim()) {
      setError('Address is required for Sundry Debtors and Sundry Creditors.');
      setSuccess(null);
      return;
    }
    const payload = {
      ...ledgerForm,
      group: ledgerForm.group as LedgerMasterEntry['group'],
      gstRegistrationType: ledgerForm.gstRegistrationType as LedgerMasterEntry['gstRegistrationType'],
    };
    const result = editingLedgerId ? updateLedger(editingLedgerId, payload) : addLedger(payload);
    if (!result.ok) {
      setError(result.error ?? 'Could not save ledger.');
      setSuccess(null);
      return;
    }
    setError(null);
    setSuccess(editingLedgerId ? `"${ledgerForm.name}" updated.` : `"${ledgerForm.name}" created.`);
    startNewLedger();
  }

  function fetchLedgerGstinDetails(value = ledgerForm.gstin) {
    const gstin = value.trim().toUpperCase();
    if (!/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][A-Z0-9]Z[A-Z0-9]$/.test(gstin)) {
      setError('Enter a valid 15-character GSTIN first.');
      return;
    }
    if (window.parent === window) {
      setError('GST validation is available when Billing is opened from the client portal.');
      return;
    }
    const requestId = `gstin-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    gstRequestId.current = requestId;
    setIsFetchingGst(true);
    setError(null);
    window.parent.postMessage({ source: 'sales-voucher-system', type: 'validate-gstin', requestId, gstin }, '*');
  }

  function updateLedgerGstin(value: string) {
    const gstin = value.toUpperCase().replace(/\s/g, '').slice(0, 15);
    setLedgerForm((form) => ({ ...form, gstin }));
    if (/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][A-Z0-9]Z[A-Z0-9]$/.test(gstin) && !isFetchingGst && gstRequestId.current === null) {
      window.setTimeout(() => fetchLedgerGstinDetails(gstin), 0);
    }
  }

  function saveUnit() {
    const result = addUnit(unitName);
    if (!result.ok) {
      setError(result.error ?? 'Could not save unit.');
      setSuccess(null);
      return;
    }
    setError(null);
    setSuccess(`Unit "${unitName.trim()}" created.`);
    setUnitName('');
  }

  function saveCategory() {
    const result = addCategory(categoryName);
    if (!result.ok) {
      setError(result.error ?? 'Could not save category.');
      setSuccess(null);
      return;
    }
    setError(null);
    setSuccess(`Category "${categoryName.trim()}" created.`);
    setCategoryName('');
  }

  const itemNameDuplicate = itemForm.name.trim() !== '' && isDuplicateItemName(itemForm.name, editingItemId ?? undefined);
  const ledgerNameDuplicate =
    ledgerForm.name.trim() !== '' && isDuplicateLedgerName(ledgerForm.name, editingLedgerId ?? undefined);
  const unitNameDuplicate = unitName.trim() !== '' && isDuplicateUnitName(unitName);
  const categoryNameDuplicate = categoryName.trim() !== '' && isDuplicateCategoryName(categoryName);

  const inputCls =
    'w-full rounded-md border border-slate-300 bg-white px-2.5 py-1.5 text-sm outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100';
  const label = 'block text-[11px] font-semibold uppercase tracking-wide text-slate-500 mb-1';

  function handleUnitFieldCreate(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.altKey && e.key.toLowerCase() === 'c') {
      e.preventDefault();
      const name = itemForm.unit.trim();
      if (!name || isDuplicateUnitName(name)) return;
      const result = addUnit(name);
      if (result.ok) setSuccess(`Unit "${name}" created.`);
    }
  }

  function handleCategoryFieldCreate(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.altKey && e.key.toLowerCase() === 'c') {
      e.preventDefault();
      const name = itemForm.category.trim();
      if (!name || isDuplicateCategoryName(name)) return;
      const result = addCategory(name);
      if (result.ok) setSuccess(`Category "${name}" created.`);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-6">
      <div className="flex h-full max-h-[720px] w-full max-w-4xl flex-col rounded-lg bg-white shadow-2xl">
        <div className="flex items-center justify-between border-b border-slate-200 px-5 py-3">
          <h2 className="text-sm font-bold uppercase tracking-wide text-slate-700">Masters</h2>
          <button onClick={onClose} className="text-slate-400 hover:text-slate-700" aria-label="Close">
            ✕
          </button>
        </div>

        <div className="flex border-b border-slate-200 px-5">
          {(['items', 'ledgers', 'units', 'categories', 'voucherSeries'] as Tab[]).map((t) => (
            <button
              key={t}
              onClick={() => switchTab(t)}
              className={`border-b-2 px-4 py-2 text-xs font-semibold uppercase tracking-wide ${
                tab === t ? 'border-blue-600 text-blue-700' : 'border-transparent text-slate-400 hover:text-slate-600'
              }`}
            >
              {TAB_LABEL[t]}
            </button>
          ))}
        </div>

        {tab === 'voucherSeries' ? (
          <div className="overflow-auto p-5"><VoucherNumberingPanel /></div>
        ) : (
        <div className="flex flex-1 overflow-hidden">
          {/* List */}
          <div className="flex w-1/2 flex-col border-r border-slate-200">
            <div className="border-b border-slate-100 p-3">
              <input
                className={inputCls}
                placeholder={`Search ${TAB_LABEL[tab].toLowerCase()}...`}
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <div className="flex-1 overflow-auto">
              {tab === 'items' && (
                <table className="w-full text-sm">
                  <thead className="sticky top-0 bg-slate-100 text-[11px] font-semibold uppercase text-slate-600">
                    <tr>
                      <th className="px-3 py-2 text-left">Name</th>
                      <th className="px-3 py-2 text-left">Category</th>
                      <th className="px-3 py-2 text-right">Rate</th>
                      <th className="px-3 py-2 text-right">GST%</th>
                      <th className="px-3 py-2 text-right">Stock</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredItems.map((i) => (
                      <tr
                        key={i.id}
                        onClick={() => startEditItem(i)}
                        className={`cursor-pointer border-b border-slate-50 hover:bg-blue-50 ${
                          editingItemId === i.id ? 'bg-blue-50' : ''
                        }`}
                      >
                        <td className="px-3 py-1.5">{i.name}</td>
                        <td className="px-3 py-1.5 text-slate-500">{i.category || '—'}</td>
                        <td className="px-3 py-1.5 text-right">{i.rate}</td>
                        <td className="px-3 py-1.5 text-right">{i.gstPercent}%</td>
                        <td className="px-3 py-1.5 text-right">{i.stockQty ?? 0}</td>
                      </tr>
                    ))}
                    {filteredItems.length === 0 && (
                      <tr>
                        <td colSpan={5} className="px-3 py-6 text-center text-slate-400">
                          No items found.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              )}
              {tab === 'ledgers' && (
                <table className="w-full text-sm">
                  <thead className="sticky top-0 bg-slate-100 text-[11px] font-semibold uppercase text-slate-600">
                    <tr>
                      <th className="px-3 py-2 text-left">Name</th>
                      <th className="px-3 py-2 text-left">Group</th>
                      <th className="px-3 py-2 text-left">GST Type</th>
                      <th className="px-3 py-2 text-right">Opening Bal.</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredLedgers.map((l) => (
                      <tr
                        key={l.id}
                        onClick={() => startEditLedger(l)}
                        className={`cursor-pointer border-b border-slate-50 hover:bg-blue-50 ${
                          editingLedgerId === l.id ? 'bg-blue-50' : ''
                        }`}
                      >
                        <td className="px-3 py-1.5">{l.name}</td>
                        <td className="px-3 py-1.5 text-slate-500">{l.group}</td>
                        <td className="px-3 py-1.5 text-slate-500">{l.gstRegistrationType}</td>
                        <td className="px-3 py-1.5 text-right">{l.openingBalance}</td>
                      </tr>
                    ))}
                    {filteredLedgers.length === 0 && (
                      <tr>
                        <td colSpan={4} className="px-3 py-6 text-center text-slate-400">
                          No ledgers found.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              )}
              {tab === 'units' && (
                <table className="w-full text-sm">
                  <thead className="sticky top-0 bg-slate-100 text-[11px] font-semibold uppercase text-slate-600">
                    <tr>
                      <th className="px-3 py-2 text-left">Unit Name</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredUnits.map((u) => (
                      <tr key={u.id} className="border-b border-slate-50">
                        <td className="px-3 py-1.5">{u.name}</td>
                      </tr>
                    ))}
                    {filteredUnits.length === 0 && (
                      <tr>
                        <td className="px-3 py-6 text-center text-slate-400">No units found.</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              )}
              {tab === 'categories' && (
                <table className="w-full text-sm">
                  <thead className="sticky top-0 bg-slate-100 text-[11px] font-semibold uppercase text-slate-600">
                    <tr>
                      <th className="px-3 py-2 text-left">Category Name</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredCategories.map((c) => (
                      <tr key={c.id} className="border-b border-slate-50">
                        <td className="px-3 py-1.5">{c.name}</td>
                      </tr>
                    ))}
                    {filteredCategories.length === 0 && (
                      <tr>
                        <td className="px-3 py-6 text-center text-slate-400">No categories found.</td>
                      </tr>
                    )}
                  </tbody>
                </table>
              )}
            </div>
          </div>

          {/* Form */}
          <div className="flex w-1/2 flex-col overflow-auto p-4">
            <div className="mb-3 flex items-center justify-between">
              <h3 className="text-xs font-bold uppercase tracking-wide text-slate-600">
                {tab === 'items' && (editingItemId ? 'Alter Item' : 'Create Item')}
                {tab === 'ledgers' && (editingLedgerId ? 'Alter Ledger' : 'Create Ledger')}
                {tab === 'units' && 'Create Unit'}
                {tab === 'categories' && 'Create Category'}
              </h3>
              {(tab === 'items' || tab === 'ledgers') && (
                <button
                  onClick={tab === 'items' ? startNewItem : startNewLedger}
                  className="text-xs font-medium text-blue-600 hover:underline"
                >
                  + New
                </button>
              )}
            </div>

            {error && <div className="mb-3 rounded-md bg-rose-50 px-3 py-2 text-xs font-medium text-rose-700">⚠ {error}</div>}
            {success && (
              <div className="mb-3 rounded-md bg-emerald-50 px-3 py-2 text-xs font-medium text-emerald-700">✓ {success}</div>
            )}

            {tab === 'items' && (
              <div className="space-y-3">
                <div>
                  <label className={label}>Item Name</label>
                  <input
                    className={`${inputCls} ${itemNameDuplicate ? 'border-amber-400 bg-amber-50' : ''}`}
                    value={itemForm.name}
                    onChange={(e) => setItemForm((f) => ({ ...f, name: e.target.value }))}
                  />
                  {itemNameDuplicate && <p className="mt-1 text-xs text-amber-600">⚠ This item name already exists.</p>}
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className={label}>Barcode</label>
                    <input
                      className={inputCls}
                      value={itemForm.barcode}
                      onChange={(e) => setItemForm((f) => ({ ...f, barcode: e.target.value }))}
                    />
                  </div>
                  <div>
                    <label className={label}>HSN/SAC</label>
                    <input
                      className={inputCls}
                      value={itemForm.hsn}
                      onChange={(e) => setItemForm((f) => ({ ...f, hsn: e.target.value }))}
                    />
                  </div>
                  <div>
                    <label className={label}>Unit (Alt+C to create)</label>
                    <input
                      className={inputCls}
                      list="masters-unit-list"
                      value={itemForm.unit}
                      onChange={(e) => setItemForm((f) => ({ ...f, unit: e.target.value }))}
                      onKeyDown={handleUnitFieldCreate}
                      title="Type a new unit and press Alt+C to add it to the Unit master"
                    />
                    <datalist id="masters-unit-list">
                      {units.map((u) => (
                        <option key={u.id} value={u.name} />
                      ))}
                    </datalist>
                  </div>
                  <div>
                    <label className={label}>Category (Alt+C to create)</label>
                    <input
                      className={inputCls}
                      list="masters-category-list"
                      value={itemForm.category}
                      onChange={(e) => setItemForm((f) => ({ ...f, category: e.target.value }))}
                      onKeyDown={handleCategoryFieldCreate}
                      title="Type a new category and press Alt+C to add it to the Category master"
                    />
                    <datalist id="masters-category-list">
                      {categories.map((c) => (
                        <option key={c.id} value={c.name} />
                      ))}
                    </datalist>
                  </div>
                  <div>
                    <label className={label}>Rate</label>
                    <input
                      type="number"
                      className={inputCls}
                      value={itemForm.rate || ''}
                      onChange={(e) => setItemForm((f) => ({ ...f, rate: Number(e.target.value) || 0 }))}
                    />
                  </div>
                  <div>
                    <label className={label}>GST %</label>
                    <input
                      type="number"
                      className={inputCls}
                      value={itemForm.gstPercent || ''}
                      onChange={(e) => setItemForm((f) => ({ ...f, gstPercent: Number(e.target.value) || 0 }))}
                    />
                  </div>
                  <div>
                    <label className={label}>Closing Stock Qty</label>
                    <input
                      type="number"
                      className={inputCls}
                      value={itemForm.stockQty || ''}
                      onChange={(e) => setItemForm((f) => ({ ...f, stockQty: Number(e.target.value) || 0 }))}
                    />
                  </div>
                </div>
                <button
                  onClick={saveItem}
                  disabled={!itemForm.name.trim() || itemNameDuplicate}
                  className="w-full rounded-md bg-blue-600 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-700 disabled:cursor-not-allowed disabled:bg-slate-300"
                >
                  {editingItemId ? 'Save Changes' : 'Create Item'}
                </button>
              </div>
            )}

            {tab === 'ledgers' && (
              <div className="space-y-3">
                <fieldset className="border border-slate-200 bg-slate-50 p-3">
                  <legend className="px-1 text-[11px] font-bold uppercase tracking-wide text-slate-600">Ledger Details</legend>
                  <div className="space-y-3">
                    <div>
                      <label className={label}>Name</label>
                      <input className={`${inputCls} ${ledgerNameDuplicate ? 'border-amber-400 bg-amber-50' : ''}`} value={ledgerForm.name} onChange={(e) => setLedgerForm((form) => ({ ...form, name: e.target.value }))} />
                      {ledgerNameDuplicate && <p className="mt-1 text-xs text-amber-600">This ledger name already exists.</p>}
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className={label}>Under</label>
                        <select className={inputCls} value={ledgerForm.group} onChange={(e) => setLedgerForm((form) => ({ ...form, group: e.target.value }))} disabled={isGstLedgerName(ledgerForm.name)}>
                          {LEDGER_GROUPS.map((group) => <option key={group} value={group}>{group}</option>)}
                        </select>
                      </div>
                      <div>
                        <label className={label}>Opening Balance</label>
                        <input type="number" className={inputCls} value={ledgerForm.openingBalance || ''} onChange={(e) => setLedgerForm((form) => ({ ...form, openingBalance: Number(e.target.value) || 0 }))} />
                      </div>
                    </div>
                    {isGstLedgerName(ledgerForm.name) && <p className="text-xs text-blue-600">GST-named ledgers are placed under Duties &amp; Taxes.</p>}
                  </div>
                </fieldset>
                <fieldset className="border border-slate-200 bg-slate-50 p-3">
                  <legend className="px-1 text-[11px] font-bold uppercase tracking-wide text-slate-600">Statutory &amp; GST Details</legend>
                  <div className="space-y-3">
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className={label}>Registration Type</label>
                        <select className={inputCls} value={ledgerForm.gstRegistrationType} onChange={(e) => setLedgerForm((form) => ({ ...form, gstRegistrationType: e.target.value }))}>
                          {GST_REGISTRATION_TYPES.map((type) => <option key={type} value={type}>{type}</option>)}
                        </select>
                      </div>
                      <div>
                        <label className={label}>GSTIN</label>
                        <input className={inputCls} value={ledgerForm.gstin} maxLength={15} placeholder="15-character GSTIN" onChange={(e) => updateLedgerGstin(e.target.value)} onBlur={() => fetchLedgerGstinDetails()} />
                      </div>
                    </div>
                    <button type="button" onClick={() => fetchLedgerGstinDetails()} disabled={isFetchingGst || !ledgerForm.gstin.trim()} className="w-full rounded-md border border-blue-200 bg-blue-50 py-2 text-sm font-semibold text-blue-700 hover:bg-blue-100 disabled:cursor-not-allowed disabled:border-slate-200 disabled:bg-slate-100 disabled:text-slate-400">
                      {isFetchingGst ? 'Fetching GST details...' : 'Fetch GST Details'}
                    </button>
                  </div>
                </fieldset>
                <fieldset className="border border-slate-200 bg-slate-50 p-3">
                  <legend className="px-1 text-[11px] font-bold uppercase tracking-wide text-slate-600">Mailing &amp; Contact Details</legend>
                  <div className="space-y-3">
                    <AddressLocationForm title={ledgerForm.group === 'Sundry Debtors' || ledgerForm.group === 'Sundry Creditors' ? 'Mailing Address *' : 'Mailing Address'} value={ledgerForm.location} onChange={(location) => setLedgerForm((form) => ({ ...form, location }))} />
                    <div className="grid grid-cols-2 gap-3">
                      <div><label className={label}>Contact Person</label><input className={inputCls} value={ledgerForm.contactName} onChange={(e) => setLedgerForm((form) => ({ ...form, contactName: e.target.value }))} /></div>
                      <div><label className={label}>Mobile</label><input className={inputCls} inputMode="tel" value={ledgerForm.mobile} onChange={(e) => setLedgerForm((form) => ({ ...form, mobile: e.target.value }))} /></div>
                      <div className="col-span-2"><label className={label}>Email</label><input className={inputCls} type="email" value={ledgerForm.email} onChange={(e) => setLedgerForm((form) => ({ ...form, email: e.target.value }))} /></div>
                    </div>
                  </div>
                </fieldset>
                <button
                  onClick={saveLedger}
                  disabled={!ledgerForm.name.trim() || ledgerNameDuplicate}
                  className="w-full rounded-md bg-blue-600 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-700 disabled:cursor-not-allowed disabled:bg-slate-300"
                >
                  {editingLedgerId ? 'Save Changes' : 'Create Ledger'}
                </button>
              </div>
            )}

            {tab === 'units' && (
              <div className="space-y-3">
                <div>
                  <label className={label}>Unit Name</label>
                  <input
                    className={`${inputCls} ${unitNameDuplicate ? 'border-amber-400 bg-amber-50' : ''}`}
                    value={unitName}
                    onChange={(e) => setUnitName(e.target.value)}
                    placeholder="e.g. Doz, Pair, Ream"
                  />
                  {unitNameDuplicate && <p className="mt-1 text-xs text-amber-600">⚠ This unit already exists.</p>}
                </div>
                <button
                  onClick={saveUnit}
                  disabled={!unitName.trim() || unitNameDuplicate}
                  className="w-full rounded-md bg-blue-600 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-700 disabled:cursor-not-allowed disabled:bg-slate-300"
                >
                  Create Unit
                </button>
              </div>
            )}

            {tab === 'categories' && (
              <div className="space-y-3">
                <div>
                  <label className={label}>Category Name</label>
                  <input
                    className={`${inputCls} ${categoryNameDuplicate ? 'border-amber-400 bg-amber-50' : ''}`}
                    value={categoryName}
                    onChange={(e) => setCategoryName(e.target.value)}
                    placeholder="e.g. Electronics, Stationery"
                  />
                  {categoryNameDuplicate && <p className="mt-1 text-xs text-amber-600">⚠ This category already exists.</p>}
                </div>
                <button
                  onClick={saveCategory}
                  disabled={!categoryName.trim() || categoryNameDuplicate}
                  className="w-full rounded-md bg-blue-600 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-700 disabled:cursor-not-allowed disabled:bg-slate-300"
                >
                  Create Category
                </button>
              </div>
            )}
          </div>
        </div>
        )}
      </div>
    </div>
  );
}
