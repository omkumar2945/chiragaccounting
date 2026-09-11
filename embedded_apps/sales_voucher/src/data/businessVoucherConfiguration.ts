import type {
  BusinessVoucherConfiguration,
  VoucherTemplateConfiguration,
  VoucherType,
} from '../types';
import { VOUCHER_SHORTCUTS } from './voucherShortcuts';

const categoryFor = (type: VoucherType): VoucherTemplateConfiguration['category'] => {
  if (['Contra', 'Payment', 'Receipt', 'Journal'].includes(type)) return 'ledger';
  if (type === 'Stock Journal') return 'stock';
  if (type === 'Manufacturing Journal') return 'manufacturing';
  return 'item';
};

function defaultConfiguration(): BusinessVoucherConfiguration {
  return {
    clientId: 'client',
    profileVersion: 0,
    businessTypes: [],
    businessNatures: [],
    vouchers: VOUCHER_SHORTCUTS.map(({ type, shortcutLabel }) => ({
      voucherType: type,
      shortcut: shortcutLabel,
      category: categoryFor(type),
      dynamicFields: [],
      units: ['Nos', 'Pc'],
      taxSuggestions: [],
      enabled: true,
      inventoryEnabled: true,
      printFormat: 'A4 Tax Invoice',
    })),
    documents: [],
    generatedAt: '',
  };
}

export function businessVoucherConfigurationFromUrl(): BusinessVoucherConfiguration {
  const encoded = new URLSearchParams(window.location.search).get('voucherConfiguration');
  if (!encoded) return defaultConfiguration();
  try {
    const parsed = JSON.parse(encoded) as Partial<BusinessVoucherConfiguration>;
    const fallback = defaultConfiguration();
    return {
      ...fallback,
      ...parsed,
      businessTypes: Array.isArray(parsed.businessTypes) ? parsed.businessTypes : [],
      businessNatures: Array.isArray(parsed.businessNatures) ? parsed.businessNatures : [],
      vouchers: Array.isArray(parsed.vouchers) && parsed.vouchers.length
        ? parsed.vouchers
        : fallback.vouchers,
      documents: Array.isArray(parsed.documents) ? parsed.documents : [],
    };
  } catch {
    return defaultConfiguration();
  }
}

export function voucherConfigurationFor(
  configuration: BusinessVoucherConfiguration,
  voucherType: VoucherType,
): VoucherTemplateConfiguration {
  return configuration.vouchers.find((voucher) => voucher.voucherType === voucherType)
    ?? defaultConfiguration().vouchers.find((voucher) => voucher.voucherType === voucherType)!;
}

export function voucherTypeForDocument(document: string): VoucherType {
  if (['Production', 'Consumption', 'Job Work Inward', 'Job Work Outward'].includes(document)) {
    return 'Manufacturing Journal';
  }
  if (['Material Inward', 'Material Outward'].includes(document)) return 'Stock Journal';
  if (['Purchase Order', 'Goods Receipt', 'Purchase Return'].includes(document)) return 'Purchase';
  if (document === 'Sales Return') return 'Credit Note';
  if (document === 'Goods Return') return 'Debit Note';
  return 'Sales';
}