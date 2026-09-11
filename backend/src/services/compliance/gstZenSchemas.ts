import { z } from 'zod';

const noQuote = /^[^"]*$/;
const gstinSchema = z.string().trim().toUpperCase().regex(/^[0-9]{2}[A-Z0-9]{13}$/);
const taxpayerGstinSchema = z.union([gstinSchema, z.literal('URP')]);
const stateCodeSchema = z.string().regex(/^(?!0+$)[0-9]{1,2}$/);
const pinCodeSchema = z.number().int().min(100000).max(999999);
const nonNegativeNumber = z.number().finite().nonnegative();
const text = (min: number, max: number) => z.string().trim().min(min).max(max).regex(noQuote);

const gstDateSchema = z.string().regex(/^\d{2}\/\d{2}\/\d{4}$/).refine((value) => {
  const [day, month, year] = value.split('/').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return year >= 2010 && year <= 2099 && date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
}, 'Invalid calendar date');

const contactShape = {
  Ph: z.string().regex(/^[0-9]{6,12}$/).optional(),
  Em: z.string().email().min(6).max(100).optional(),
};
const partyShape = {
  Gstin: taxpayerGstinSchema,
  LglNm: text(3, 100),
  TrdNm: text(3, 100).optional(),
  Addr1: text(1, 100),
  Addr2: text(3, 100).optional(),
  Loc: text(3, 100),
  Pin: pinCodeSchema.optional(),
  Stcd: stateCodeSchema,
  ...contactShape,
};
const validatePartyState = (party: { Gstin: string; Stcd: string }) =>
  party.Gstin === 'URP' || party.Gstin.startsWith(party.Stcd.padStart(2, '0'));
const sellerSchema = z.object({ ...partyShape, Gstin: gstinSchema, Pin: pinCodeSchema })
  .passthrough().refine(validatePartyState, {
    message: 'GSTIN state code must match Stcd', path: ['Gstin'],
  });
const buyerSchema = z.object({ ...partyShape, Pos: stateCodeSchema })
  .passthrough().refine(validatePartyState, {
    message: 'GSTIN state code must match Stcd', path: ['Gstin'],
  });
const dispatchSchema = z.object({
  Nm: text(3, 100), Addr1: text(1, 100), Addr2: text(3, 100).optional(),
  Loc: text(3, 100), Pin: pinCodeSchema, Stcd: stateCodeSchema,
}).passthrough();
const shippingSchema = z.object({
  Gstin: taxpayerGstinSchema.optional(), LglNm: text(3, 100),
  TrdNm: text(3, 100).optional(), Addr1: text(1, 100),
  Addr2: text(3, 100).optional(), Loc: text(3, 100), Pin: pinCodeSchema,
  Stcd: stateCodeSchema,
}).passthrough();
const exportShippingSchema = z.object({
  Gstin: text(3, 15), TrdNm: text(3, 100), Addr1: text(1, 100),
  Addr2: text(3, 100).optional(), Loc: text(3, 100), Pin: pinCodeSchema,
  Stcd: stateCodeSchema,
}).passthrough();

const itemSchema = z.object({
  ItemNo: z.number().int().nonnegative().optional(),
  SlNo: z.string().regex(/^[0-9]{1,6}$/),
  PrdDesc: text(3, 300).optional(), IsServc: z.enum(['Y', 'N']),
  HsnCd: z.string().regex(/^(?!0+$)(?:[0-9]{4}|[0-9]{6}|[0-9]{8})$/),
  Barcde: text(3, 30).optional(), Qty: nonNegativeNumber.max(9999999999.999).optional(),
  FreeQty: nonNegativeNumber.max(9999999999.999).optional(),
  Unit: z.string().regex(/^[A-Za-z]{3,8}$/).optional(),
  UnitPrice: nonNegativeNumber.max(999999999999.999),
  TotAmt: nonNegativeNumber.max(999999999999.99),
  Discount: nonNegativeNumber.max(999999999999.99).optional(),
  PreTaxVal: nonNegativeNumber.max(999999999999.99).optional(),
  AssAmt: nonNegativeNumber.max(999999999999.99), GstRt: nonNegativeNumber.max(999.999),
  IgstAmt: nonNegativeNumber.max(999999999999.99).optional(),
  CgstAmt: nonNegativeNumber.max(999999999999.99).optional(),
  SgstAmt: nonNegativeNumber.max(999999999999.99).optional(),
  CesRt: nonNegativeNumber.max(999.999).optional(),
  CesAmt: nonNegativeNumber.max(999999999999.99).optional(),
  CesNonAdvlAmt: nonNegativeNumber.max(999999999999.99).optional(),
  StateCesRt: nonNegativeNumber.max(999.999).optional(),
  StateCesAmt: nonNegativeNumber.max(999999999999.99).optional(),
  StateCesNonAdvlAmt: nonNegativeNumber.max(999999999999.99).optional(),
  OthChrg: nonNegativeNumber.max(999999999999.99).optional(),
  TotItemVal: nonNegativeNumber.max(999999999999.99),
  OrdLineRef: text(1, 50).optional(), OrgCntry: z.string().regex(/^[A-Za-z]{2}$/).optional(),
  PrdSlNo: text(1, 20).optional(),
  BchDtls: z.object({ Nm: text(3, 20), ExpDt: gstDateSchema.optional(), WrDt: gstDateSchema.optional() }).passthrough().optional(),
  AttribDtls: z.array(z.object({ Nm: text(1, 100), Val: text(1, 100) }).passthrough()).optional(),
}).passthrough();

const paymentSchema = z.object({
  Nm: text(1, 100).optional(), AccDet: text(1, 18).optional(), Mode: text(1, 18).optional(),
  FinInsBr: text(1, 11).optional(), PayTerm: text(1, 100).optional(),
  PayInstr: text(1, 100).optional(), CrTrn: text(1, 100).optional(),
  DirDr: text(1, 100).optional(), CrDay: nonNegativeNumber.max(9999).optional(),
  PaidAmt: nonNegativeNumber.max(99999999999999.99).optional(),
  PaymtDue: nonNegativeNumber.max(99999999999999.99).optional(),
}).passthrough();
const referenceSchema = z.object({
  InvRm: text(3, 100).optional(),
  DocPerdDtls: z.object({ InvStDt: gstDateSchema, InvEndDt: gstDateSchema }).passthrough().optional(),
  PrecDocDtls: z.array(z.object({
    InvNo: z.string().min(1).max(16), InvDt: gstDateSchema,
    OthRefNo: text(1, 20).optional(),
  }).passthrough()).optional(),
  ContrDtls: z.array(z.record(z.unknown())).optional(),
}).passthrough();
const exportSchema = z.object({
  ShipBNo: text(1, 20).optional(), ShipBDt: gstDateSchema.optional(),
  Port: z.string().regex(/^[A-Za-z0-9]{2,10}$/).optional(), RefClm: z.enum(['Y', 'N']).optional(),
  ForCur: z.string().regex(/^[A-Za-z]{3,16}$/).optional(),
  CntCode: z.string().regex(/^[A-Z]{2}$/).optional(),
  ExpDuty: nonNegativeNumber.max(999999999999.99).optional(),
}).passthrough();
const ewayDetailsSchema = z.object({
  TransId: gstinSchema.optional(), TransName: text(3, 100).optional(),
  TransMode: z.enum(['1', '2', '3', '4']).optional(), Distance: z.number().int().min(0).max(4000),
  TransDocNo: z.string().regex(/^[A-Za-z0-9/-]{1,15}$/).optional(),
  TransDocDt: gstDateSchema.optional(), VehNo: z.string().regex(/^[A-Za-z0-9]{4,20}$/).optional(),
  VehType: z.enum(['R', 'O']).optional(),
}).passthrough();

export const gstZenEInvoiceSchema = z.object({
  Version: z.string().min(1).max(6), Irn: z.string().length(64).optional(),
  TranDtls: z.object({
    TaxSch: z.literal('GST'), SupTyp: z.enum(['B2B', 'SEZWP', 'SEZWOP', 'EXPWP', 'EXPWOP', 'DEXP']),
    RegRev: z.enum(['Y', 'N']).optional(), EcmGstin: gstinSchema.optional(),
    IgstOnIntra: z.enum(['Y', 'N']).optional(),
  }).passthrough(),
  DocDtls: z.object({
    Typ: z.enum(['INV', 'CRN', 'DBN']), No: z.string().regex(/^[A-Za-z1-9][A-Za-z0-9/-]{0,15}$/),
    Dt: gstDateSchema,
  }).passthrough(),
  SellerDtls: sellerSchema, BuyerDtls: buyerSchema,
  DispDtls: dispatchSchema.optional(), ShipDtls: shippingSchema.optional(),
  ItemList: z.array(itemSchema).min(1),
  ValDtls: z.object({
    AssVal: nonNegativeNumber.max(99999999999999.99),
    CgstVal: nonNegativeNumber.max(99999999999999.99).optional(),
    SgstVal: nonNegativeNumber.max(99999999999999.99).optional(),
    IgstVal: nonNegativeNumber.max(99999999999999.99).optional(),
    CesVal: nonNegativeNumber.max(99999999999999.99).optional(),
    StCesVal: nonNegativeNumber.max(99999999999999.99).optional(),
    Discount: nonNegativeNumber.max(99999999999999.99).optional(),
    OthChrg: nonNegativeNumber.max(99999999999999.99).optional(),
    RndOffAmt: z.number().finite().min(-99.99).max(99.99).optional(),
    TotInvVal: nonNegativeNumber.max(99999999999999.99),
    TotInvValFc: nonNegativeNumber.max(99999999999999.99).optional(),
  }).passthrough(),
  PayDtls: paymentSchema.optional(), RefDtls: referenceSchema.optional(),
  AddlDocDtls: z.array(z.record(z.unknown())).optional(), ExpDtls: exportSchema.optional(),
  ExpShipDtls: exportShippingSchema.optional(), EwbDtls: ewayDetailsSchema.optional(),
}).passthrough();

export const gstZenEWayBillOnIrnSchema = gstZenEInvoiceSchema.extend({
  EwbDtls: ewayDetailsSchema,
});
const gstZenGetEInvoiceSchema = z.object({
  SellerDtls: z.object({
    Gstin: gstinSchema,
  }).strict(),
  Irn: z.string().regex(/^[A-Fa-f0-9]{64}$/),
  irp: text(1, 20).optional(),
}).strict();

const ewbNumberSchema = z.union([
  z.number().int().positive(),
  z.string().regex(/^\d{10,12}$/),
]);
const ewbStateSchema = z.number().int().min(1).max(99);
const ewbVehicleSchema = z.string().trim().min(4).max(20);
const ewbModeSchema = z.enum(['1', '2', '3', '4']);
const optionalEwbText = (max: number) => z.string().trim().max(max);
const standaloneItemSchema = z.object({
  productName: text(1, 100),
  productDesc: text(1, 300),
  hsnCode: z.number().int().min(1).max(99999999),
  quantity: nonNegativeNumber,
  qtyUnit: z.string().regex(/^[A-Za-z]{3,8}$/),
  cgstRate: nonNegativeNumber,
  sgstRate: nonNegativeNumber,
  igstRate: nonNegativeNumber,
  cessRate: nonNegativeNumber,
  cessNonadvol: nonNegativeNumber,
  taxableAmount: nonNegativeNumber,
}).passthrough();

const standaloneEWayBillSchemas = {
  create: z.object({
    supplyType: z.enum(['I', 'O']),
    subSupplyType: z.string().regex(/^\d{1,2}$/),
    subSupplyDesc: optionalEwbText(100),
    docType: text(1, 5),
    docNo: text(1, 16),
    docDate: gstDateSchema,
    fromGstin: gstinSchema,
    fromTrdName: text(1, 100),
    fromAddr1: text(1, 120),
    fromAddr2: optionalEwbText(120),
    fromPlace: text(1, 50),
    fromPincode: pinCodeSchema,
    actFromStateCode: ewbStateSchema,
    fromStateCode: ewbStateSchema,
    toGstin: taxpayerGstinSchema,
    toTrdName: text(1, 100),
    toAddr1: text(1, 120),
    toAddr2: optionalEwbText(120),
    toPlace: text(1, 50),
    toPincode: pinCodeSchema,
    actToStateCode: ewbStateSchema,
    toStateCode: ewbStateSchema,
    transactionType: z.number().int().min(1).max(4),
    shipToGSTIN: taxpayerGstinSchema.optional(),
    shipToTradeName: text(1, 100).optional(),
    otherValue: z.union([nonNegativeNumber, z.string().regex(/^\d+(?:\.\d+)?$/)]),
    totalValue: nonNegativeNumber,
    cgstValue: nonNegativeNumber,
    sgstValue: nonNegativeNumber,
    igstValue: nonNegativeNumber,
    cessValue: nonNegativeNumber,
    cessNonAdvolValue: nonNegativeNumber,
    totInvValue: nonNegativeNumber,
    transporterId: z.union([gstinSchema, z.literal('')]),
    transporterName: optionalEwbText(100),
    transDocNo: optionalEwbText(15),
    transMode: ewbModeSchema,
    transDistance: z.string().regex(/^\d{1,4}$/),
    transDocDate: z.union([gstDateSchema, z.literal('')]),
    vehicleNo: ewbVehicleSchema,
    vehicleType: z.enum(['R', 'O']),
    itemList: z.array(standaloneItemSchema).min(1),
  }).passthrough(),
  cancel: z.object({
    cancelRmrk: text(1, 100),
    cancelRsnCode: z.number().int().min(1).max(4),
    ewbNo: ewbNumberSchema,
  }).passthrough(),
  updatePartB: z.object({
    ewbNo: ewbNumberSchema,
    FromPlace: text(1, 50),
    FromState: ewbStateSchema,
    ReasonCode: z.string().regex(/^\d{1,2}$/),
    ReasonRem: text(1, 100),
    TransDocDate: gstDateSchema,
    TransDocNo: text(1, 15),
    TransMode: ewbModeSchema,
    VehicleNo: ewbVehicleSchema,
  }).passthrough(),
  updateTransporter: z.object({
    ewbNo: ewbNumberSchema,
    transporterId: gstinSchema,
  }).passthrough(),
  get: z.object({ ewbNo: ewbNumberSchema }).passthrough(),
  consolidate: z.object({
    fromPlace: text(1, 50),
    fromState: ewbStateSchema,
    vehicleNo: ewbVehicleSchema,
    transMode: ewbModeSchema,
    transDocNo: text(1, 15),
    transDocDate: gstDateSchema,
    tripSheetEwbBills: z.array(z.object({ ewbNo: ewbNumberSchema }).strict()).min(1),
  }).passthrough(),
  getConsolidated: z.object({
    tripSheetNo: z.union([z.number().int().positive(), z.string().regex(/^\d+$/)]),
  }).passthrough(),
  extend: z.object({
    ewbNo: ewbNumberSchema,
    vehicleNo: ewbVehicleSchema,
    fromPlace: text(1, 50),
    fromState: ewbStateSchema,
    fromPincode: pinCodeSchema,
    remainingDistance: z.number().int().min(0).max(4000),
    transDocNo: text(1, 15),
    transDocDate: gstDateSchema,
    transMode: ewbModeSchema,
    extnRsnCode: z.number().int().min(1).max(99),
    extnRemarks: text(1, 100),
    transitType: optionalEwbText(10),
    consignmentStatus: z.enum(['M', 'T']),
  }).passthrough(),
  initiateMultiVehicle: z.object({
    ewbNo: ewbNumberSchema,
    reasonCode: z.string().regex(/^\d{1,2}$/),
    reasonRem: text(1, 100),
    fromPlace: text(1, 50),
    fromState: ewbStateSchema,
    toPlace: text(1, 50),
    toState: ewbStateSchema,
    transMode: ewbModeSchema,
    totalQuantity: nonNegativeNumber,
    unitCode: z.string().regex(/^[A-Za-z]{3,8}$/),
  }).passthrough(),
  addMultiVehicle: z.object({
    ewbNo: ewbNumberSchema,
    groupNo: z.union([z.number().int().positive(), z.string().regex(/^\d+$/)]),
    vehicleNo: ewbVehicleSchema,
    transDocNo: text(1, 15),
    transDocDate: gstDateSchema,
    quantity: nonNegativeNumber,
  }).passthrough(),
  changeMultiVehicle: z.object({
    ewbNo: ewbNumberSchema,
    groupNo: z.union([z.number().int().positive(), z.string().regex(/^\d+$/)]),
    oldvehicleNo: ewbVehicleSchema,
    newVehicleNo: ewbVehicleSchema,
    oldTranNo: text(1, 15),
    newTranNo: text(1, 15),
    fromPlace: text(1, 50),
    fromState: ewbStateSchema,
    reasonCode: z.string().regex(/^\d{1,2}$/),
    reasonRem: text(1, 100),
  }).passthrough(),
  close: z.object({
    ewbNo: ewbNumberSchema,
    closureDate: gstDateSchema,
    remarks: text(1, 100),
  }).passthrough(),
} as const;

export type GstZenStandaloneEWayBillAction = keyof typeof standaloneEWayBillSchemas;

function parsePayload(
  schema: z.ZodType<Record<string, unknown>>,
  payload: Record<string, unknown>,
  errorCode: string,
) {
  const result = schema.safeParse(payload);
  if (result.success) return result.data;

  const details = result.error.issues
    .map((issue) => `${issue.path.join('.') || 'payload'}: ${issue.message}`)
    .join('; ');
  throw new Error(`${errorCode}:${details}`);
}

export function parseGstZenEInvoicePayload(payload: Record<string, unknown>) {
  return parsePayload(
    gstZenEInvoiceSchema,
    payload,
    'GSTZEN_INVALID_EINVOICE_PAYLOAD',
  );
}

export function parseGstZenEWayBillOnIrnPayload(payload: Record<string, unknown>) {
  return parsePayload(
    gstZenEWayBillOnIrnSchema,
    payload,
    'GSTZEN_INVALID_EWAY_BILL_ON_IRN_PAYLOAD',
  );
}

export function parseGstZenCancelEWayBillOnIrnPayload(
  payload: Record<string, unknown>,
) {
  return parsePayload(
    gstZenEInvoiceSchema,
    payload,
    'GSTZEN_INVALID_CANCEL_EWAY_BILL_ON_IRN_PAYLOAD',
  );
}

export function parseGstZenGetEInvoicePayload(payload: Record<string, unknown>) {
  return parsePayload(
    gstZenGetEInvoiceSchema,
    payload,
    'GSTZEN_INVALID_GET_EINVOICE_PAYLOAD',
  );
}

export function parseGstZenStandaloneEWayBillPayload(
  action: GstZenStandaloneEWayBillAction,
  payload: Record<string, unknown>,
) {
  return parsePayload(
    standaloneEWayBillSchemas[action],
    payload,
    `GSTZEN_INVALID_EWAY_BILL_${action.toUpperCase()}_PAYLOAD`,
  );
}