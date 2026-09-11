import { createContext, useContext, useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import type { ItemCategoryEntry, ItemMasterEntry, LedgerMasterEntry, UnitMasterEntry } from '../types';
import { ITEM_CATEGORY_SEED, ITEM_MASTER_SEED, LEDGER_MASTER_SEED, UNIT_MASTER_SEED } from '../data/masters';

const ITEMS_KEY = 'chirag_item_master_v1';
const LEDGERS_KEY = 'chirag_ledger_master_v1';
const UNITS_KEY = 'chirag_unit_master_v1';
const CATEGORIES_KEY = 'chirag_category_master_v1';

let idCounter = 1;
const nextId = (prefix: string) => `${prefix}-${Date.now()}-${idCounter++}`;

function loadFromStorage<T>(key: string, seed: T[]): T[] {
  try {
    const raw = localStorage.getItem(key);
    if (raw) return JSON.parse(raw) as T[];
  } catch {
    /* ignore corrupted storage, fall back to seed */
  }
  return seed;
}

function normalize(name: string): string {
  return name.trim().toLowerCase();
}

/** True when a ledger name contains GST/CGST/SGST/IGST as a whole word (per GST norms). */
export function isGstLedgerName(name: string): boolean {
  const words = name.toLowerCase().split(/[^a-z]+/i);
  return words.some((w) => w === 'gst' || w === 'cgst' || w === 'sgst' || w === 'igst');
}

interface MastersContextValue {
  items: ItemMasterEntry[];
  ledgers: LedgerMasterEntry[];
  units: UnitMasterEntry[];
  categories: ItemCategoryEntry[];
  findItemByName: (name: string) => ItemMasterEntry | undefined;
  findItemByBarcode: (barcode: string) => ItemMasterEntry | undefined;
  searchItems: (query: string) => ItemMasterEntry[];
  isDuplicateItemName: (name: string, excludeId?: string) => boolean;
  addItem: (item: Omit<ItemMasterEntry, 'id'>) => { ok: boolean; error?: string };
  updateItem: (id: string, patch: Omit<ItemMasterEntry, 'id'>) => { ok: boolean; error?: string };
  isDuplicateLedgerName: (name: string, excludeId?: string) => boolean;
  addLedger: (ledger: Omit<LedgerMasterEntry, 'id'>) => { ok: boolean; error?: string };
  updateLedger: (id: string, patch: Omit<LedgerMasterEntry, 'id'>) => { ok: boolean; error?: string };
  isDuplicateUnitName: (name: string, excludeId?: string) => boolean;
  addUnit: (name: string) => { ok: boolean; error?: string };
  isDuplicateCategoryName: (name: string, excludeId?: string) => boolean;
  addCategory: (name: string) => { ok: boolean; error?: string };
}

const MastersContext = createContext<MastersContextValue | null>(null);

export function MastersProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ItemMasterEntry[]>(() => loadFromStorage(ITEMS_KEY, ITEM_MASTER_SEED));
  const [ledgers, setLedgers] = useState<LedgerMasterEntry[]>(() => loadFromStorage(LEDGERS_KEY, LEDGER_MASTER_SEED));
  const [units, setUnits] = useState<UnitMasterEntry[]>(() => loadFromStorage(UNITS_KEY, UNIT_MASTER_SEED));
  const [categories, setCategories] = useState<ItemCategoryEntry[]>(() =>
    loadFromStorage(CATEGORIES_KEY, ITEM_CATEGORY_SEED)
  );

  useEffect(() => {
    localStorage.setItem(ITEMS_KEY, JSON.stringify(items));
  }, [items]);
  useEffect(() => {
    localStorage.setItem(LEDGERS_KEY, JSON.stringify(ledgers));
  }, [ledgers]);
  useEffect(() => {
    localStorage.setItem(UNITS_KEY, JSON.stringify(units));
  }, [units]);
  useEffect(() => {
    localStorage.setItem(CATEGORIES_KEY, JSON.stringify(categories));
  }, [categories]);

  function findItemByName(name: string) {
    return items.find((i) => normalize(i.name) === normalize(name));
  }

  function findItemByBarcode(barcode: string) {
    const value = normalize(barcode);
    if (!value) return undefined;
    return items.find((i) => normalize(i.barcode ?? '').includes(value));
  }

  function searchItems(query: string) {
    const q = normalize(query);
    if (!q) return [];
    return items
      .filter((i) => normalize(i.name).includes(q) || normalize(i.barcode ?? '').includes(q))
      .slice(0, 6);
  }

  function isDuplicateItemName(name: string, excludeId?: string) {
    const n = normalize(name);
    if (!n) return false;
    return items.some((i) => i.id !== excludeId && normalize(i.name) === n);
  }

  function addItem(item: Omit<ItemMasterEntry, 'id'>): { ok: boolean; error?: string } {
    if (!item.name.trim()) return { ok: false, error: 'Item name is required.' };
    if (isDuplicateItemName(item.name)) {
      return { ok: false, error: `An item named "${item.name.trim()}" already exists.` };
    }
    setItems((prev) => [...prev, { ...item, id: nextId('item') }]);
    return { ok: true };
  }

  function updateItem(id: string, patch: Omit<ItemMasterEntry, 'id'>): { ok: boolean; error?: string } {
    if (!patch.name.trim()) return { ok: false, error: 'Item name is required.' };
    if (isDuplicateItemName(patch.name, id)) {
      return { ok: false, error: `An item named "${patch.name.trim()}" already exists.` };
    }
    setItems((prev) => prev.map((i) => (i.id === id ? { ...patch, id } : i)));
    return { ok: true };
  }

  function isDuplicateLedgerName(name: string, excludeId?: string) {
    const n = normalize(name);
    if (!n) return false;
    return ledgers.some((l) => l.id !== excludeId && normalize(l.name) === n);
  }

  /** GST duty/tax ledgers (CGST/SGST/IGST/GST) always belong under Duties & Taxes, per GST norms. */
  function resolveLedgerGroup(name: string, group: LedgerMasterEntry['group']): LedgerMasterEntry['group'] {
    return isGstLedgerName(name) ? 'Duties & Taxes' : group;
  }

  function addLedger(ledger: Omit<LedgerMasterEntry, 'id'>): { ok: boolean; error?: string } {
    if (!ledger.name.trim()) return { ok: false, error: 'Ledger name is required.' };
    if (isDuplicateLedgerName(ledger.name)) {
      return { ok: false, error: `A ledger named "${ledger.name.trim()}" already exists.` };
    }
    const resolved = { ...ledger, group: resolveLedgerGroup(ledger.name, ledger.group) };
    setLedgers((prev) => [...prev, { ...resolved, id: nextId('ledger') }]);
    return { ok: true };
  }

  function updateLedger(id: string, patch: Omit<LedgerMasterEntry, 'id'>): { ok: boolean; error?: string } {
    if (!patch.name.trim()) return { ok: false, error: 'Ledger name is required.' };
    if (isDuplicateLedgerName(patch.name, id)) {
      return { ok: false, error: `A ledger named "${patch.name.trim()}" already exists.` };
    }
    const resolved = { ...patch, group: resolveLedgerGroup(patch.name, patch.group) };
    setLedgers((prev) => prev.map((l) => (l.id === id ? { ...resolved, id } : l)));
    return { ok: true };
  }

  function isDuplicateUnitName(name: string, excludeId?: string) {
    const n = normalize(name);
    if (!n) return false;
    return units.some((u) => u.id !== excludeId && normalize(u.name) === n);
  }

  function addUnit(name: string): { ok: boolean; error?: string } {
    if (!name.trim()) return { ok: false, error: 'Unit name is required.' };
    if (isDuplicateUnitName(name)) {
      return { ok: false, error: `A unit named "${name.trim()}" already exists.` };
    }
    setUnits((prev) => [...prev, { id: nextId('unit'), name: name.trim() }]);
    return { ok: true };
  }

  function isDuplicateCategoryName(name: string, excludeId?: string) {
    const n = normalize(name);
    if (!n) return false;
    return categories.some((c) => c.id !== excludeId && normalize(c.name) === n);
  }

  function addCategory(name: string): { ok: boolean; error?: string } {
    if (!name.trim()) return { ok: false, error: 'Category name is required.' };
    if (isDuplicateCategoryName(name)) {
      return { ok: false, error: `A category named "${name.trim()}" already exists.` };
    }
    setCategories((prev) => [...prev, { id: nextId('cat'), name: name.trim() }]);
    return { ok: true };
  }

  return (
    <MastersContext.Provider
      value={{
        items,
        ledgers,
        units,
        categories,
        findItemByName,
        findItemByBarcode,
        searchItems,
        isDuplicateItemName,
        addItem,
        updateItem,
        isDuplicateLedgerName,
        addLedger,
        updateLedger,
        isDuplicateUnitName,
        addUnit,
        isDuplicateCategoryName,
        addCategory,
      }}
    >
      {children}
    </MastersContext.Provider>
  );
}

export function useMasters(): MastersContextValue {
  const ctx = useContext(MastersContext);
  if (!ctx) throw new Error('useMasters must be used within a MastersProvider');
  return ctx;
}
