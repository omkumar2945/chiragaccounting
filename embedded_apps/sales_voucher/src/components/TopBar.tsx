import { useLayoutEffect, useRef, useState } from 'react';
import type { BusinessVoucherConfiguration, ClientProfile, EntryMode, VoucherType } from '../types';
import { voucherCategory } from '../types';
import { VOUCHER_SHORTCUTS } from '../data/voucherShortcuts';
import { DOCUMENT_SHORTCUTS } from '../data/documentShortcuts';

interface TopBarProps {
  clientProfile: ClientProfile;
  voucherType: VoucherType;
  documentType: string;
  onVoucherTypeChange: (t: VoucherType) => void;
  configuration: BusinessVoucherConfiguration;
  onDocumentSelect: (document: string) => void;
  mode: EntryMode;
  onModeChange: (m: EntryMode) => void;
  onOpenBusinessTemplate: () => void;
  onOpenMasters: () => void;
  onOpenImport: () => void;
  onOpenRegisters: () => void;
}

const MORE_BUTTON_RESERVED_WIDTH = 76;

export default function TopBar({ clientProfile, voucherType, documentType, onVoucherTypeChange, configuration, onDocumentSelect, mode, onModeChange, onOpenBusinessTemplate, onOpenMasters, onOpenImport, onOpenRegisters }: TopBarProps) {
  const isItemVoucher = voucherCategory(voucherType) === 'item';
  const [billingMenuOpen, setBillingMenuOpen] = useState(false);
  const [moreMenuOpen, setMoreMenuOpen] = useState(false);
  const enabledVoucherTypes = new Set(
    configuration.vouchers.filter((voucher) => voucher.enabled).map((voucher) => voucher.voucherType),
  );
  const shortcuts = VOUCHER_SHORTCUTS.filter((shortcut) => enabledVoucherTypes.has(shortcut.type));
  const documentBoxes = configuration.documents.map((document) => ({
    document,
    shortcutLabel: DOCUMENT_SHORTCUTS.find((s) => s.document === document)?.shortcutLabel ?? '',
  }));
  const menuItems = [
    ...shortcuts.map((s) => ({
      key: s.type,
      label: voucherLabelFor(s.type),
      shortcutLabel: s.shortcutLabel,
      active: voucherType === s.type,
      onClick: () => selectVoucher(s.type),
    })),
    ...documentBoxes.map((d) => ({
      key: d.document,
      label: d.document,
      shortcutLabel: d.shortcutLabel,
      active: documentType === d.document,
      onClick: () => selectDocument(d.document),
    })),
  ];

  // Fits as many boxes as possible in one row; the rest collapse behind a "More" box at the end of the filled row.
  const menuRowRef = useRef<HTMLDivElement>(null);
  const menuItemRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const menuItemsKey = menuItems.map((item) => item.key).join('|');
  const [visibleCount, setVisibleCount] = useState(menuItems.length);

  useLayoutEffect(() => {
    setVisibleCount(menuItems.length);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [menuItemsKey]);

  useLayoutEffect(() => {
    function recalcVisibleCount() {
      const row = menuRowRef.current;
      if (!row || menuItems.length === 0) return;
      const availableWidth = row.clientWidth;
      let usedWidth = 0;
      let fitCount = 0;
      for (let i = 0; i < menuItems.length; i++) {
        const itemWidth = (menuItemRefs.current[i]?.offsetWidth ?? 0) + 4;
        const isLastItem = i === menuItems.length - 1;
        const reserve = isLastItem ? 0 : MORE_BUTTON_RESERVED_WIDTH;
        if (usedWidth + itemWidth + reserve > availableWidth) break;
        usedWidth += itemWidth;
        fitCount++;
      }
      setVisibleCount(Math.max(1, fitCount));
    }
    recalcVisibleCount();
    const observer = new ResizeObserver(recalcVisibleCount);
    if (menuRowRef.current) observer.observe(menuRowRef.current);
    return () => observer.disconnect();
  }, [menuItemsKey, menuItems.length]);

  const overflowStartsAt = Math.min(visibleCount, menuItems.length);
  const visibleMenuItems = menuItems.slice(0, overflowStartsAt);
  const overflowMenuItems = menuItems.slice(overflowStartsAt);
  const initials = (clientProfile.firmName || clientProfile.clientName || 'CL')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join('') || 'CL';

  function selectVoucher(type: VoucherType) {
    onVoucherTypeChange(type);
    setBillingMenuOpen(false);
    setMoreMenuOpen(false);
  }

  function selectDocument(document: string) {
    onDocumentSelect(document);
    setMoreMenuOpen(false);
  }

  function voucherLabelFor(type: VoucherType) {
    return type === 'Manufacturing Journal' ? 'Stock / Material Transfer' : type;
  }

  const voucherLabel = voucherLabelFor;

  return (
    <header className="bg-slate-900 text-white shadow-md">
      <div className="flex flex-nowrap items-center justify-between gap-3 px-5 py-2.5">
        <div className="flex shrink-0 items-center gap-3">
          <div className="flex h-8 w-8 items-center justify-center rounded bg-blue-600 font-bold text-sm">
            {initials}
          </div>
          <div>
            <div className="text-sm font-semibold leading-tight">{clientProfile.clientName || clientProfile.firmName}</div>
            <div className="text-[11px] text-slate-400 leading-tight">
              {clientProfile.firmName}{clientProfile.mobile ? ` | ${clientProfile.mobile}` : ''}
            </div>
          </div>
        </div>

        <div className="flex flex-nowrap items-center gap-2 overflow-x-auto">
          <button
            type="button"
            onClick={onOpenBusinessTemplate}
            className="shrink-0 whitespace-nowrap rounded-md border border-blue-500 bg-blue-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-blue-500"
          >
            Universal Business Template System
          </button>
          <div className="relative shrink-0">
            <button
              type="button"
              onClick={() => setBillingMenuOpen((open) => !open)}
              aria-expanded={billingMenuOpen}
              aria-haspopup="menu"
              className="whitespace-nowrap rounded-md border border-blue-500 bg-blue-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-blue-500"
            >
              Billing System
            </button>
            {billingMenuOpen && (
              <div
                role="menu"
                aria-label="Billing System vouchers"
                className="absolute right-0 z-30 mt-1 w-52 overflow-hidden rounded-md border border-slate-200 bg-white py-1 text-slate-700 shadow-lg"
              >
                {shortcuts.map((shortcut) => (
                  <button
                    key={shortcut.type}
                    type="button"
                    role="menuitem"
                    onClick={() => selectVoucher(shortcut.type)}
                    className={`flex w-full items-center justify-between px-3 py-2 text-left text-xs hover:bg-slate-100 ${
                      voucherType === shortcut.type ? 'bg-blue-50 font-semibold text-blue-700' : ''
                    }`}
                  >
                    <span>{voucherLabel(shortcut.type)}</span>
                    <span className="text-[10px] text-slate-400">{shortcut.shortcutLabel}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
          <button
            onClick={onOpenMasters}
            className="shrink-0 whitespace-nowrap rounded-md border border-slate-700 bg-slate-800 px-3 py-1.5 text-xs font-semibold text-slate-200 hover:bg-slate-700"
          >
            📒 Masters
          </button>
          <button
            onClick={onOpenImport}
            className="shrink-0 whitespace-nowrap rounded-md border border-slate-700 bg-slate-800 px-3 py-1.5 text-xs font-semibold text-slate-200 hover:bg-slate-700"
          >
            ⬇ Import
          </button>
          <button
            onClick={onOpenRegisters}
            className="shrink-0 whitespace-nowrap rounded-md border border-slate-700 bg-slate-800 px-3 py-1.5 text-xs font-semibold text-slate-200 hover:bg-slate-700"
          >
            Registers
          </button>
          {isItemVoucher && (
            <div className="flex shrink-0 whitespace-nowrap rounded-md bg-slate-800 p-0.5 text-xs font-medium">
              <button
                onClick={() => onModeChange('standard')}
                className={`rounded px-3 py-1.5 transition-colors ${
                  mode === 'standard' ? 'bg-emerald-600 text-white' : 'text-slate-300 hover:text-white'
                }`}
              >
                Manual Entry
              </button>
              <button
                onClick={() => onModeChange('ai')}
                className={`rounded px-3 py-1.5 transition-colors ${
                  mode === 'ai' ? 'bg-emerald-600 text-white' : 'text-slate-300 hover:text-white'
                }`}
              >
                ✨ AI Invoice Entry
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Hidden measurement row: same boxes rendered off-screen so we can read their natural widths */}
      <div
        aria-hidden="true"
        className="pointer-events-none invisible absolute flex items-center gap-1 px-5 py-1.5"
      >
        {menuItems.map((item, index) => (
          <button
            key={item.key}
            ref={(el) => {
              menuItemRefs.current[index] = el;
            }}
            className="flex shrink-0 items-center gap-1 rounded border px-1.5 py-1 text-[11px] font-medium"
          >
            {item.shortcutLabel && (
              <span className="rounded px-1 py-0.5 text-[9px] font-bold">{item.shortcutLabel}</span>
            )}
            <span className="whitespace-nowrap">{item.label}</span>
          </button>
        ))}
      </div>

      {/* Tally-style voucher menu: small boxes stay in a single row; extras collapse into a "More" box at the end.
          The "More" dropdown lives outside the overflow-hidden row so its popup isn't clipped. */}
      <div className="flex items-center gap-1 border-t border-slate-800 bg-slate-950 px-5 py-1.5">
        <div ref={menuRowRef} className="flex min-w-0 flex-1 items-center gap-1 overflow-hidden">
          {visibleMenuItems.map((item) => (
            <button
              key={item.key}
              onClick={item.onClick}
              title={item.label}
              className={`flex shrink-0 items-center gap-1 rounded border px-1.5 py-1 text-[11px] font-medium transition-colors ${
                item.active
                  ? 'border-blue-500 bg-blue-600 text-white'
                  : 'border-slate-800 bg-slate-900 text-slate-300 hover:border-slate-600 hover:bg-slate-800 hover:text-white'
              }`}
            >
              {item.shortcutLabel && (
                <span
                  className={`rounded px-1 py-0.5 text-[9px] font-bold ${
                    item.active ? 'bg-blue-800 text-blue-100' : 'bg-slate-700 text-slate-300'
                  }`}
                >
                  {item.shortcutLabel}
                </span>
              )}
              <span className="whitespace-nowrap">{item.label}</span>
            </button>
          ))}
        </div>
        {overflowMenuItems.length > 0 && (
          <div className="relative shrink-0">
            <button
              type="button"
              onClick={() => setMoreMenuOpen((open) => !open)}
              aria-expanded={moreMenuOpen}
              aria-haspopup="menu"
              className={`flex items-center gap-1 rounded border px-1.5 py-1 text-[11px] font-medium transition-colors ${
                overflowMenuItems.some((item) => item.active)
                  ? 'border-blue-500 bg-blue-600 text-white'
                  : 'border-slate-800 bg-slate-900 text-slate-300 hover:border-slate-600 hover:bg-slate-800 hover:text-white'
              }`}
            >
              More ▾
            </button>
            {moreMenuOpen && (
              <div
                role="menu"
                aria-label="More vouchers"
                className="absolute right-0 top-full z-30 mt-1 max-h-72 w-56 overflow-auto rounded-md border border-slate-200 bg-white py-1 text-slate-700 shadow-lg"
              >
                {overflowMenuItems.map((item) => (
                  <button
                    key={item.key}
                    type="button"
                    role="menuitem"
                    onClick={(e) => {
                      e.stopPropagation();
                      item.onClick();
                    }}
                    className={`flex w-full items-center justify-between px-3 py-2 text-left text-xs hover:bg-slate-100 ${
                      item.active ? 'bg-blue-50 font-semibold text-blue-700' : ''
                    }`}
                  >
                    <span>{item.label}</span>
                    {item.shortcutLabel && (
                      <span className="text-[10px] text-slate-400">{item.shortcutLabel}</span>
                    )}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </header>
  );
}
