import { useEffect, useMemo, useState } from 'react';
import type {
  ClientProfile,
  EntryMode,
  EwayTransportData,
  ItemRow,
  LedgerEntry,
  ManufacturingMaterialRow,
  ManufacturingOutput,
  SimpleVoucherHeaderData,
  StockEntryRow,
  VoucherHeaderData,
  VoucherType,
} from './types';
import TopBar from './components/TopBar';
import VoucherHeaderForm from './components/VoucherHeaderForm';
import { emptyAddress } from './components/AddressLocationForm';
import SimpleVoucherHeader from './components/SimpleVoucherHeader';
import EwayTransportSection from './components/EwayTransportSection';
import ItemGrid from './components/ItemGrid';
import LedgerVoucherEntry from './components/LedgerVoucherEntry';
import StockJournalGrid from './components/StockJournalGrid';
import ManufacturingJournalEntry from './components/ManufacturingJournalEntry';
import TotalsPanel from './components/TotalsPanel';
import ActionBar from './components/ActionBar';
import AIInvoiceEntry from './components/AIInvoiceEntry';
import MastersPanel from './components/MastersPanel';
import ImportCenter from './components/ImportCenter';
import Toast from './components/Toast';
import VoucherRegisters from './components/VoucherRegisters';
import {
  computeLedgerTotals,
  computeStockTotals,
  computeVoucherTotals,
  createEmptyLedgerRow,
  createEmptyManufacturingMaterialRow,
  createEmptyManufacturingOutput,
  createEmptyRow,
  createEmptyStockRow,
} from './utils/calculations';
import { isDuplicateInvoiceNo, registerVoucher } from './store/voucherRegister';
import { makeVoucherNumber, markNumberUsed } from './store/voucherNumbering';
import { VOUCHER_SHORTCUTS } from './data/voucherShortcuts';
import { DOCUMENT_SHORTCUTS } from './data/documentShortcuts';
import {
  businessVoucherConfigurationFromUrl,
  voucherConfigurationFor,
  voucherTypeForDocument,
} from './data/businessVoucherConfiguration';

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

function clientProfileFromUrl(): ClientProfile {
  const params = new URLSearchParams(window.location.search);
  return {
    clientId: params.get('clientId')?.trim() || 'client',
    clientName: params.get('clientName')?.trim() || 'Client',
    firmName: params.get('firmName')?.trim() || params.get('clientName')?.trim() || 'Client Billing',
    email: params.get('email')?.trim() || '',
    mobile: params.get('mobile')?.trim() || '',
  };
}

function initialVoucherTypeFromUrl(): VoucherType {
  const initialType = new URLSearchParams(window.location.search).get('initialVoucherType');
  return initialType === 'Purchase' ||
      initialType === 'Debit Note' ||
      initialType === 'Credit Note' ||
      initialType === 'Payment' ||
      initialType === 'Receipt' ||
      initialType === 'Journal' ||
      initialType === 'Contra' ||
      initialType === 'Stock Journal' ||
      initialType === 'Manufacturing Journal'
    ? initialType
    : 'Sales';
}

function makeVoucherNo(type: VoucherType) {
  return makeVoucherNumber(type);
}

function emptyHeader(type: VoucherType): VoucherHeaderData {
  return {
    voucherNo: makeVoucherNo(type),
    voucherDate: todayISO(),
    partyName: '',
    partyGSTIN: '',
    placeOfSupply: 'Karnataka',
    billingLocation: { ...emptyAddress(), stateId: '29', stateName: 'Karnataka' },
    shippingLocation: emptyAddress(),
    invoiceNo: '',
    invoiceDate: todayISO(),
    paymentTerms: '',
    ledger: type === 'Sales' ? 'Sales A/c - GST 18%' : 'Purchase A/c - GST 18%',
    against: '',
    reason: '',
  };
}

function emptySimpleHeader(type: VoucherType): SimpleVoucherHeaderData {
  return {
    voucherNo: makeVoucherNo(type),
    voucherDate: todayISO(),
    referenceNo: '',
    narration: '',
  };
}

function emptyEwayTransport(): EwayTransportData {
  return {
    irn: '',
    ackNo: '',
    ackDate: '',
    ewayBillNo: '',
    ewayBillDate: '',
    ewayValidUpto: '',
    transporterName: '',
    transporterId: '',
    vehicleNo: '',
    modeOfTransport: 'Road',
    distanceKm: 0,
    lrNo: '',
    lrDate: '',
    placeOfDelivery: '',
  };
}

const REFERENCE_LABEL: Partial<Record<VoucherType, string>> = {
  Payment: 'Cheque / UTR No.',
  Receipt: 'Cheque / UTR No.',
  Journal: 'Reference No.',
  Contra: 'Cheque / Txn No.',
  'Stock Journal': 'Reference No.',
};

export default function App() {
  const [clientProfile] = useState<ClientProfile>(() => clientProfileFromUrl());
  const [businessConfiguration] = useState(() => businessVoucherConfigurationFromUrl());
  const [voucherType, setVoucherType] = useState<VoucherType>(() => initialVoucherTypeFromUrl());
  const [documentType, setDocumentType] = useState('');
  const [mode, setMode] = useState<EntryMode>('standard');
  const activeConfiguration = voucherConfigurationFor(businessConfiguration, voucherType);
  const manufacturingDocument = ['Production', 'Consumption', 'Job Work Inward', 'Job Work Outward']
    .includes(documentType);
  const category = manufacturingDocument ? 'manufacturing' : activeConfiguration.category;

  const [header, setHeader] = useState<VoucherHeaderData>(() => emptyHeader(initialVoucherTypeFromUrl()));
  const [rows, setRows] = useState<ItemRow[]>(() => [createEmptyRow('row-1')]);
  const [eway, setEway] = useState<EwayTransportData>(() => emptyEwayTransport());

  const [simpleHeader, setSimpleHeader] = useState<SimpleVoucherHeaderData>(() => emptySimpleHeader(initialVoucherTypeFromUrl()));
  const [ledgerRows, setLedgerRows] = useState<LedgerEntry[]>(() => [
    createEmptyLedgerRow('ledger-1'),
    createEmptyLedgerRow('ledger-2'),
  ]);
  const [stockRows, setStockRows] = useState<StockEntryRow[]>(() => [createEmptyStockRow('stock-1')]);
  const [manufacturingOutput, setManufacturingOutput] = useState<ManufacturingOutput>(() => createEmptyManufacturingOutput());
  const [manufacturingMaterials, setManufacturingMaterials] = useState<ManufacturingMaterialRow[]>(() => [
    createEmptyManufacturingMaterialRow('material-1'),
  ]);

  const [toast, setToast] = useState<{ message: string; kind: 'success' | 'error' } | null>(null);
  const [showMasters, setShowMasters] = useState(false);
  const [masterTarget, setMasterTarget] = useState<{ tab: 'items' | 'ledgers'; id: string } | null>(null);
  const [showImport, setShowImport] = useState(false);
  const [showRegisters, setShowRegisters] = useState(false);

  function notify(message: string, kind: 'success' | 'error') {
    setToast({ message, kind });
  }

  function openAlterItem(id: string) {
    setMasterTarget({ tab: 'items', id });
    setShowMasters(true);
  }

  function openAlterLedger(id: string) {
    setMasterTarget({ tab: 'ledgers', id });
    setShowMasters(true);
  }

  function handleAutoPullPurchase(headerPatch: Partial<VoucherHeaderData>, importedRows: ItemRow[]) {
    setVoucherType('Purchase');
    setMode('standard');
    setHeader({ ...emptyHeader('Purchase'), ...headerPatch, ledger: 'Purchase A/c - GST 18%' });
    setRows(importedRows.length ? importedRows : [createEmptyRow('row-1')]);
    setEway(emptyEwayTransport());
  }

  const totals = useMemo(() => computeVoucherTotals(rows, header.placeOfSupply), [rows, header.placeOfSupply]);
  const ledgerTotals = useMemo(() => computeLedgerTotals(ledgerRows), [ledgerRows]);
  const stockTotals = useMemo(() => computeStockTotals(stockRows), [stockRows]);

  const activeVoucherNo = category === 'item' ? header.voucherNo : simpleHeader.voucherNo;

  function handleVoucherTypeChange(t: VoucherType) {
    const target = voucherConfigurationFor(businessConfiguration, t);
    if (!target.enabled) return;
    setVoucherType(t);
    setDocumentType('');
    setMode('standard');
    setHeader(emptyHeader(t));
    setRows([createEmptyRow('row-1')]);
    setEway(emptyEwayTransport());
    setSimpleHeader(emptySimpleHeader(t));
    setLedgerRows([createEmptyLedgerRow('ledger-1'), createEmptyLedgerRow('ledger-2')]);
    setStockRows([createEmptyStockRow('stock-1')]);
    setManufacturingOutput(createEmptyManufacturingOutput());
    setManufacturingMaterials([createEmptyManufacturingMaterialRow('material-1')]);
  }

  function handleDocumentSelect(document: string) {
    const targetType = voucherTypeForDocument(document);
    const target = voucherConfigurationFor(businessConfiguration, targetType);
    if (!target.enabled) {
      notify(`${document} is not enabled for the selected business activities.`, 'error');
      return;
    }
    handleVoucherTypeChange(targetType);
    setDocumentType(document);
  }

  function resetVoucher() {
    setHeader(emptyHeader(voucherType));
    setRows([createEmptyRow('row-1')]);
    setEway(emptyEwayTransport());
    setSimpleHeader(emptySimpleHeader(voucherType));
    setLedgerRows([createEmptyLedgerRow('ledger-1'), createEmptyLedgerRow('ledger-2')]);
    setStockRows([createEmptyStockRow('stock-1')]);
    setManufacturingOutput(createEmptyManufacturingOutput());
    setManufacturingMaterials([createEmptyManufacturingMaterialRow('material-1')]);
  }

  function validate(): string | null {
    if (category === 'item') {
      if (voucherType === 'Credit Note' || voucherType === 'Debit Note') {
        if (!header.against.trim()) return 'Against Bill is required for this note.';
        if (!header.reason.trim()) return 'For What Reason is required for this note.';
      }
      if (!header.partyName.trim()) return 'Party A/c Name is required.';
      if (!header.invoiceNo.trim()) return 'Invoice No. is required.';
      if (isDuplicateInvoiceNo(voucherType, header.invoiceNo)) {
        return `Invoice No. "${header.invoiceNo.trim()}" is already used for a ${voucherType} voucher. Please enter a unique invoice number.`;
      }
      const validRows = rows.filter((r) => r.itemName.trim() && r.qty > 0);
      if (validRows.length === 0) return 'Add at least one item with a quantity.';
      return null;
    }
    if (category === 'ledger') {
      const validRows = ledgerRows.filter((r) => r.ledgerName.trim() && (r.drAmount > 0 || r.crAmount > 0));
      if (validRows.length < 2) return 'Add at least two ledger entries.';
      if (!ledgerTotals.balanced) return 'Debit and Credit totals must be equal before saving.';
      return null;
    }
    if (category === 'manufacturing') {
      if (!manufacturingOutput.itemName.trim() || manufacturingOutput.qty <= 0) {
        return 'Enter the finished good and production quantity for inward.';
      }
      const validMaterials = manufacturingMaterials.filter((row) => row.itemName.trim() && row.qty > 0);
      if (validMaterials.length === 0) return 'Add at least one BOQ raw material with a quantity.';
      return null;
    }
    const validRows = stockRows.filter((r) => r.itemName.trim() && r.qty > 0);
    if (validRows.length === 0) return 'Add at least one item with a quantity.';
    return null;
  }

  function registerSavedVoucher() {
    const common = {
      clientId: clientProfile.clientId,
      clientName: clientProfile.clientName,
      firmName: clientProfile.firmName,
      voucherType,
      documentType: documentType || undefined,
      voucherNo: activeVoucherNo,
    };
    if (category === 'item') {
      registerVoucher({
        ...common,
        invoiceNo: header.invoiceNo,
        taxableAmount: totals.taxableAmount,
        grandTotal: totals.grandTotal,
        totalAmount: totals.grandTotal,
        voucherDate: header.voucherDate,
        referenceNo: header.against,
        narration: header.reason,
        ledgerNames: [header.partyName, header.ledger, ...rows.filter((row) => row.itemName.trim()).map((row) => row.itemName)],
      });
      window.parent?.postMessage(
        {
          source: 'sales-voucher-system',
          type: 'voucher-saved',
          clientId: clientProfile.clientId,
          voucherType,
          voucherNo: header.voucherNo,
          invoiceNo: header.invoiceNo,
          header,
          rows,
          totals,
          documentType: documentType || undefined,
          voucherConfiguration: activeConfiguration,
        },
        window.location.origin,
      );
      markNumberUsed(voucherType, header.voucherDate);
      return;
    }
    if (category === 'ledger') {
      registerVoucher({
        ...common,
        invoiceNo: '',
        voucherDate: simpleHeader.voucherDate,
        referenceNo: simpleHeader.referenceNo,
        narration: simpleHeader.narration,
        ledgerNames: ledgerRows.filter((row) => row.ledgerName.trim()).map((row) => row.ledgerName),
        totalAmount: ledgerTotals.totalDr,
      });
      markNumberUsed(voucherType, simpleHeader.voucherDate);
      return;
    }
    if (category === 'manufacturing') {
      registerVoucher({
        ...common,
        invoiceNo: '',
        voucherDate: simpleHeader.voucherDate,
        referenceNo: simpleHeader.referenceNo,
        narration: simpleHeader.narration,
        ledgerNames: [manufacturingOutput.itemName, ...manufacturingMaterials.filter((row) => row.itemName.trim()).map((row) => row.itemName)],
        totalAmount: manufacturingOutput.qty * manufacturingOutput.rate,
      });
      markNumberUsed(voucherType, simpleHeader.voucherDate);
      return;
    }
    registerVoucher({
      ...common,
      invoiceNo: '',
      voucherDate: simpleHeader.voucherDate,
      referenceNo: simpleHeader.referenceNo,
      narration: simpleHeader.narration,
      ledgerNames: stockRows.filter((row) => row.itemName.trim()).map((row) => row.itemName),
      stockMovements: stockRows
        .filter((row) => row.itemName.trim() && row.qty > 0)
        .map((row) => `${row.itemName}: ${row.qty} ${row.unit} outward from ${row.fromGodown}, inward to ${row.toGodown}`),
      totalAmount: stockTotals.totalValue,
    });
    markNumberUsed(voucherType, simpleHeader.voucherDate);
  }

  function handleSave() {
    const error = validate();
    if (error) {
      setToast({ message: error, kind: 'error' });
      return;
    }
    registerSavedVoucher();
    setToast({ message: `${voucherType} voucher ${activeVoucherNo} saved successfully.`, kind: 'success' });
  }

  function handleSaveAndPrint() {
    const error = validate();
    if (error) {
      setToast({ message: error, kind: 'error' });
      return;
    }
    registerSavedVoucher();
    setToast({ message: `Voucher ${activeVoucherNo} saved. Sending to printer…`, kind: 'success' });
    window.print();
  }

  function handleSaveAndNew() {
    const error = validate();
    if (error) {
      setToast({ message: error, kind: 'error' });
      return;
    }
    registerSavedVoucher();
    setToast({ message: `Voucher ${activeVoucherNo} saved. Ready for new entry.`, kind: 'success' });
    resetVoucher();
  }

  function handlePreview() {
    setToast({ message: 'Preview generated (print dialog).', kind: 'success' });
    window.print();
  }

  function handleCancel() {
    resetVoucher();
    setToast({ message: 'Voucher entry cleared.', kind: 'error' });
  }

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (e.ctrlKey && e.key.toLowerCase() === 's') {
        e.preventDefault();
        handleSave();
      } else if (e.ctrlKey && e.key.toLowerCase() === 'p') {
        e.preventDefault();
        handleSaveAndPrint();
      } else if (e.ctrlKey && e.key.toLowerCase() === 'n') {
        e.preventDefault();
        handleSaveAndNew();
      } else if (e.key === 'Escape') {
        handleCancel();
      } else {
        const shortcut = VOUCHER_SHORTCUTS.find((s) => s.matches(e));
        const documentShortcut = DOCUMENT_SHORTCUTS.find((s) => s.matches(e));
        if (shortcut && voucherConfigurationFor(businessConfiguration, shortcut.type).enabled) {
          e.preventDefault();
          handleVoucherTypeChange(shortcut.type);
        } else if (documentShortcut && businessConfiguration.documents.includes(documentShortcut.document)) {
          e.preventDefault();
          handleDocumentSelect(documentShortcut.document);
        }
      }
    }
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [header, rows, ledgerRows, stockRows, simpleHeader]);

  return (
    <div
      className={`voucher-application flex h-screen w-screen flex-col overflow-hidden bg-slate-100 ${
        activeConfiguration.printFormat.toLowerCase().includes('thermal') ? 'print-thermal' : 'print-a4'
      }`}
      data-print-format={activeConfiguration.printFormat}
    >
      <TopBar
        clientProfile={clientProfile}
        voucherType={voucherType}
        documentType={documentType}
        onVoucherTypeChange={handleVoucherTypeChange}
        configuration={businessConfiguration}
        onDocumentSelect={handleDocumentSelect}
        mode={mode}
        onModeChange={setMode}
        onOpenBusinessTemplate={() => window.parent?.postMessage(
          {
            source: 'sales-voucher-system',
            type: 'open-business-template',
          },
          window.location.origin,
        )}
        onOpenMasters={() => setShowMasters(true)}
        onOpenImport={() => setShowImport(true)}
        onOpenRegisters={() => setShowRegisters(true)}
      />

      <div className="flex flex-1 flex-col overflow-hidden">
        <div className="flex items-center justify-between bg-white px-5 py-1.5 border-b border-slate-200">
          <h1 className="text-sm font-bold uppercase tracking-wide text-slate-700">
            {documentType || `${voucherType} Voucher`} {category === 'item' && mode === 'ai' && '— AI Invoice Entry'}
          </h1>
          <div className="flex items-center gap-4 text-xs text-slate-500">
            <span>Client: <strong className="text-slate-700">{clientProfile.firmName}</strong></span>
            <span>Voucher No: {activeVoucherNo}</span>
            {businessConfiguration.profileVersion > 0 && (
              <span>Template v{businessConfiguration.profileVersion} · {activeConfiguration.printFormat}</span>
            )}
          </div>
        </div>

        {category === 'item' && (
          <div className="grid grid-cols-4 gap-2 border-b border-slate-200 bg-slate-50 px-5 py-2 text-xs text-slate-600">
            <div><span className="font-semibold text-slate-800">Dashboard</span> live from current voucher</div>
            <div>Taxable: <strong>Rs {totals.taxableAmount.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</strong></div>
            <div>GST: <strong>Rs {(totals.cgst + totals.sgst + totals.igst).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</strong></div>
            <div>Grand Total: <strong>Rs {totals.grandTotal.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</strong></div>
          </div>
        )}

        {category === 'item' && mode === 'standard' && (
          <div className="flex flex-1 flex-col overflow-auto">
            <VoucherHeaderForm
              voucherType={voucherType}
              data={header}
              onChange={(p) => setHeader((h) => ({ ...h, ...p }))}
              onNotify={notify}
              onAlterLedger={openAlterLedger}
            />
            <EwayTransportSection data={eway} onChange={(p) => setEway((e) => ({ ...e, ...p }))} />
            <ItemGrid
              rows={rows}
              onRowsChange={setRows}
              placeOfSupply={header.placeOfSupply}
              onNotify={notify}
              onAlterItem={openAlterItem}
              configuration={activeConfiguration}
            />
            <TotalsPanel totals={totals} />
            <ActionBar
              onSave={handleSave}
              onSaveAndPrint={handleSaveAndPrint}
              onSaveAndNew={handleSaveAndNew}
              onPreview={handlePreview}
              onCancel={handleCancel}
            />
          </div>
        )}

        {category === 'item' && mode === 'ai' && (
          <AIInvoiceEntry
            voucherType={voucherType}
            configuration={activeConfiguration}
            header={header}
            onHeaderChange={(p) => setHeader((h) => ({ ...h, ...p }))}
            rows={rows}
            onRowsChange={setRows}
            eway={eway}
            onEwayChange={(p) => setEway((e) => ({ ...e, ...p }))}
            onNotify={notify}
            onAlterItem={openAlterItem}
            onAlterLedger={openAlterLedger}
            onConfirmSave={handleSave}
            onSaveAndNew={handleSaveAndNew}
            onPrint={handleSaveAndPrint}
            onCancel={handleCancel}
          />
        )}

        {category === 'ledger' && (
          <div className="flex flex-1 flex-col overflow-hidden">
            <SimpleVoucherHeader
              data={simpleHeader}
              onChange={(p) => setSimpleHeader((h) => ({ ...h, ...p }))}
              voucherType={voucherType}
              referenceLabel={REFERENCE_LABEL[voucherType]}
            />
            <LedgerVoucherEntry
              voucherLabel={voucherType}
              rows={ledgerRows}
              onRowsChange={setLedgerRows}
              onNotify={notify}
              onAlterLedger={openAlterLedger}
            />
            <ActionBar
              onSave={handleSave}
              onSaveAndPrint={handleSaveAndPrint}
              onSaveAndNew={handleSaveAndNew}
              onPreview={handlePreview}
              onCancel={handleCancel}
            />
          </div>
        )}

        {category === 'stock' && (
          <div className="flex flex-1 flex-col overflow-hidden">
            <SimpleVoucherHeader
              data={simpleHeader}
              onChange={(p) => setSimpleHeader((h) => ({ ...h, ...p }))}
              voucherType={voucherType}
              referenceLabel={REFERENCE_LABEL[voucherType]}
            />
            <StockJournalGrid
              rows={stockRows}
              onRowsChange={setStockRows}
              onNotify={notify}
              onAlterItem={openAlterItem}
            />
            <section className="border-t border-slate-200 bg-white px-5 py-3 text-sm">
              <div className="flex justify-end gap-8 text-slate-700">
                <span>
                  Total Qty: <strong>{stockTotals.totalQty}</strong>
                </span>
                <span>
                  Total Value: <strong>₹ {stockTotals.totalValue.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</strong>
                </span>
              </div>
            </section>
            <ActionBar
              onSave={handleSave}
              onSaveAndPrint={handleSaveAndPrint}
              onSaveAndNew={handleSaveAndNew}
              onPreview={handlePreview}
              onCancel={handleCancel}
            />
          </div>
        )}

        {category === 'manufacturing' && (
          <div className="flex flex-1 flex-col overflow-hidden">
            <ManufacturingJournalEntry
              header={simpleHeader}
              output={manufacturingOutput}
              materials={manufacturingMaterials}
              onHeaderChange={(patch) => setSimpleHeader((current) => ({ ...current, ...patch }))}
              onOutputChange={(patch) => setManufacturingOutput((current) => ({ ...current, ...patch }))}
              onMaterialsChange={setManufacturingMaterials}
            />
            <ActionBar
              onSave={handleSave}
              onSaveAndPrint={handleSaveAndPrint}
              onSaveAndNew={handleSaveAndNew}
              onPreview={handlePreview}
              onCancel={handleCancel}
            />
          </div>
        )}
      </div>

      {toast && <Toast message={toast.message} kind={toast.kind} onClose={() => setToast(null)} />}
      {showMasters && (
        <MastersPanel
          initialTab={masterTarget?.tab}
          initialItemId={masterTarget?.tab === 'items' ? masterTarget.id : undefined}
          initialLedgerId={masterTarget?.tab === 'ledgers' ? masterTarget.id : undefined}
          onClose={() => {
            setShowMasters(false);
            setMasterTarget(null);
          }}
        />
      )}
      {showImport && <ImportCenter onClose={() => setShowImport(false)} onAutoPullPurchase={handleAutoPullPurchase} />}
      {showRegisters && <VoucherRegisters onClose={() => setShowRegisters(false)} />}
    </div>
  );
}
