import { afterEach, describe, expect, it, vi } from 'vitest';

const config = {
  accountEmail: 'activated@example.com',
  token: 'server-side-token',
  baseUrl: 'https://my.gstzen.in/~gstzen/a/post-einvoice-data/einvoice-json',
  ewayBillBaseUrl: 'https://my.gstzen.in/~gstzen/a/ewbapi',
  gstinValidatorUrl: 'https://my.gstzen.in/api/gstin-validator/',
};

const validEInvoicePayload = {
  Version: '1.1',
  TranDtls: {
    TaxSch: 'GST',
    SupTyp: 'B2B',
    RegRev: 'N',
    IgstOnIntra: 'N',
  },
  DocDtls: { Typ: 'INV', No: '23-24/DEM/54', Dt: '22/03/2023' },
  SellerDtls: {
    Gstin: '29AADCG4992P1ZP',
    LglNm: 'GSTZEN DEMO PRIVATE LIMITED',
    Addr1: 'Manyata Tech Park',
    Loc: 'BANGALORE',
    Pin: 560077,
    Stcd: '29',
  },
  BuyerDtls: {
    Gstin: '06AAMCS8709B1ZA',
    LglNm: 'Quality Products Private Limited',
    Pos: '06',
    Addr1: '133, Mahatma Gandhi Road',
    Loc: 'HARYANA',
    Pin: 121009,
    Stcd: '06',
  },
  ItemList: [
    {
      SlNo: '1',
      IsServc: 'N',
      PrdDesc: 'Computer Hardware',
      HsnCd: '3205',
      Qty: 25,
      Unit: 'PCS',
      UnitPrice: 200,
      TotAmt: 5000,
      AssAmt: 5000,
      GstRt: 18,
      IgstAmt: 900,
      CgstAmt: 0,
      SgstAmt: 0,
      TotItemVal: 5900,
    },
  ],
  ValDtls: {
    AssVal: 5000,
    CgstVal: 0,
    SgstVal: 0,
    IgstVal: 900,
    CesVal: 0,
    StCesVal: 0,
    Discount: 0,
    OthChrg: 0,
    RndOffAmt: 0,
    TotInvVal: 5900,
  },
};

const validEWayBillOnIrnPayload = {
  ...validEInvoicePayload,
  ItemList: validEInvoicePayload.ItemList.map((item, index) => ({
    ItemNo: index,
    ...item,
  })),
  EwbDtls: {
    TransId: '21ADAPP6261D1Z1',
    TransName: 'Just in time Shippers Pvt Limited',
    TransMode: '1',
    Distance: 0,
    VehNo: 'KA331234',
    VehType: 'R',
  },
  ExpShipDtls: {
    Gstin: '29XXXXXXXXXX',
    TrdNm: 'ABC',
    Addr1: '7th block',
    Addr2: 'kuvempu layout',
    Loc: 'Banagalore',
    Pin: 562160,
    Stcd: '29',
  },
};

const validCancelEWayBillOnIrnPayload = {
  ...validEInvoicePayload,
  ItemList: validEInvoicePayload.ItemList.map((item, index) => ({
    ItemNo: index,
    ...item,
  })),
  DispDtls: {
    Nm: 'Maharashtra Storage',
    Addr1: '133, Mahatma Gandhi Road',
    Loc: 'Bhiwandi',
    Pin: 400001,
    Stcd: '27',
  },
  ShipDtls: {
    Gstin: 'URP',
    LglNm: 'Quality Products Construction Site',
    Addr1: 'Anna Salai',
    Loc: 'Chennai',
    Pin: 600001,
    Stcd: '33',
  },
};

const standalonePayloads = {
  create: {
    supplyType: 'O', subSupplyType: '1', subSupplyDesc: '', docType: 'INV',
    docNo: 'sum/1/23/79', docDate: '07/07/2017', fromGstin: '29AAFCC9980M1ZR',
    fromTrdName: 'welton', fromAddr1: '2ND CROSS NO 59  19  A',
    fromAddr2: 'GROUND FLOOR OSBORNE ROAD', fromPlace: 'FRAZER TOWN',
    fromPincode: 560090, actFromStateCode: 29, fromStateCode: 29,
    toGstin: '29AEKPV7203E1Z9', toTrdName: 'sthuthya', toAddr1: 'Shree Nilaya',
    toAddr2: 'Dasarahosahalli', toPlace: 'Beml Nagar', toPincode: 560090,
    actToStateCode: 29, toStateCode: 27, transactionType: 4,
    shipToGSTIN: '29ABCDE8755F1Z2', shipToTradeName: 'XYZ Traders', otherValue: '0',
    totalValue: 56099, cgstValue: 0, sgstValue: 0, igstValue: 300.67,
    cessValue: 400.56, cessNonAdvolValue: 400, totInvValue: 68358,
    transporterId: '', transporterName: '', transDocNo: '', transMode: '1',
    transDistance: '100', transDocDate: '', vehicleNo: 'PVC1234', vehicleType: 'R',
    itemList: [{ productName: 'Wheat', productDesc: 'Wheat', hsnCode: 1001,
      quantity: 4, qtyUnit: 'BOX', cgstRate: 0, sgstRate: 0, igstRate: 3,
      cessRate: 3, cessNonadvol: 0, taxableAmount: 5609889 }],
  },
  cancel: { cancelRmrk: 'Cancelled the order', cancelRsnCode: 2, ewbNo: 141010282832 },
  updatePartB: { ewbNo: 111000609282, FromPlace: 'BANGALORE', FromState: 29,
    ReasonCode: '1', ReasonRem: 'vehicle broke down', TransDocDate: '12/10/2017',
    TransDocNo: '1234', TransMode: '1', VehicleNo: 'PQR1234' },
  updateTransporter: { ewbNo: '191010282840', transporterId: '29AKLPM8755F1Z2' },
  get: { ewbNo: 141010270204 },
  consolidate: { fromPlace: 'BANGALORE SOUTH', fromState: 29,
    vehicleNo: 'KA12AB1234', transMode: '1', transDocNo: '1234',
    transDocDate: '12/10/2017', tripSheetEwbBills: [
      { ewbNo: '111000609282' }, { ewbNo: '181000609270' },
    ] },
  getConsolidated: { tripSheetNo: '1610005711' },
  extend: { ewbNo: 191010282840, vehicleNo: 'PQR1234', fromPlace: 'Bengaluru',
    fromState: 29, fromPincode: 560077, remainingDistance: 50, transDocNo: '1234',
    transDocDate: '12/10/2017', transMode: '1', extnRsnCode: 1,
    extnRemarks: 'Flood', transitType: '', consignmentStatus: 'M' },
  initiate: { ewbNo: 131001111287, reasonCode: '1', reasonRem: 'vehicle broke down',
    fromPlace: 'BANGALORE', fromState: 29, toPlace: 'Chennai', toState: 33,
    transMode: '1', totalQuantity: 33, unitCode: 'NOS' },
  add: { ewbNo: 131001111287, groupNo: '1', vehicleNo: 'PQR1234',
    transDocNo: '1234', transDocDate: '12/10/2017', quantity: 15 },
  change: { ewbNo: 111000609282, groupNo: 1, oldvehicleNo: 'PQR1234',
    newVehicleNo: 'PQR1234', oldTranNo: 'ABC123', newTranNo: 'PQR123',
    fromPlace: 'Lucknow', fromState: 9, reasonCode: '1',
    reasonRem: 'vehicle broke down' },
  close: { ewbNo: 111000609282, closureDate: '21/05/2026', remarks: 'Closed the order' },
};

async function createService(
  fetcher: typeof fetch,
  overrides: Partial<typeof config> = {},
) {
  process.env.JWT_SECRET = 'unit-test-secret-unit-test-secret';
  process.env.MSSQL_SERVER = 'localhost';
  process.env.MSSQL_DATABASE = 'unit-test';
  process.env.MSSQL_USER = 'unit-test';
  process.env.MSSQL_PASSWORD = 'unit-test';
  const { GstZenService } = await import(
    '../src/services/compliance/gstZenService.js'
  );
  return new GstZenService({ ...config, ...overrides }, fetcher);
}

describe('GstZenService', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('reports the activated account email without exposing the token', async () => {
    const service = await createService(vi.fn());

    expect(service.status).toEqual({
      provider: 'GSTZen',
      configured: true,
      accountEmail: 'activated@example.com',
    });
    expect(service.status).not.toHaveProperty('token');
  });

  it('uses the GSTZen Token header for every documented API action', async () => {
    const fetcher = vi.fn().mockImplementation(async () =>
      new Response(JSON.stringify({ status: 1, message: 'ok' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
    const service = await createService(fetcher);
    const payload = validEInvoicePayload;

    await service.version();
    await service.generateEInvoice(payload);
    await service.cancelEInvoice(payload);
    await service.generateEWayBill(validEWayBillOnIrnPayload);
    await service.cancelEWayBill(payload);

    expect(fetcher.mock.calls.map(([url]) => url)).toEqual([
      `${config.baseUrl}/version/`,
      `${config.baseUrl}/`,
      `${config.baseUrl}/cancel/`,
      `${config.baseUrl}/genewb/`,
      `${config.baseUrl}/cancelewb/`,
    ]);
    for (const [, request] of fetcher.mock.calls) {
      expect(request?.headers).toMatchObject({
        Token: 'server-side-token',
        'Content-Type': 'application/json',
      });
    }
    expect(fetcher.mock.calls[0][1]?.method).toBe('GET');
    expect(fetcher.mock.calls.slice(1).every(([, request]) => request?.method === 'POST')).toBe(true);
    expect(fetcher.mock.calls[4]).toEqual([
      `${config.baseUrl}/cancelewb/`,
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          Accept: 'application/json',
          'Content-Type': 'application/json',
          Token: config.token,
        }),
      }),
    ]);
  });

  it('validates a normalized GSTIN through the dedicated backend-only endpoint', async () => {
    const fetcher = vi.fn().mockImplementation(async () =>
      new Response(JSON.stringify({ status: 1, lgnm: 'Validated Business' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
    const service = await createService(fetcher);

    await service.validateGstin('29aadcg4992p1zp');

    expect(fetcher).toHaveBeenCalledWith(
      config.gstinValidatorUrl,
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({ Token: config.token }),
        body: JSON.stringify({ gstin: '29AADCG4992P1ZP' }),
      }),
    );
    expect(() => service.validateGstin('invalid')).toThrow('GSTZEN_INVALID_GSTIN');
  });

  it('rejects calls until both activated email and token are configured', async () => {
    const unconfigured = await createService(vi.fn(), { token: '' });

    await expect(unconfigured.version()).rejects.toThrow(
      'CONFIGURATION_REQUIRED:GSTZEN_ACCOUNT_EMAIL,GSTZEN_TOKEN',
    );
  });

  it('maps every published e-invoice and standalone e-way bill operation', async () => {
    const fetcher = vi.fn().mockImplementation(async () =>
      new Response(JSON.stringify({ status: 1 }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
    const service = await createService(fetcher);
    const gstin = '29AAFCC9980M1ZR';

    await service.getEInvoice({
      SellerDtls: { Gstin: gstin },
      Irn: 'a'.repeat(64),
    });
    await service.createEWayBill(standalonePayloads.create, gstin);
    await service.cancelStandaloneEWayBill(standalonePayloads.cancel, gstin);
    await service.updateEWayBillPartB(standalonePayloads.updatePartB, gstin);
    await service.updateEWayBillTransporter(standalonePayloads.updateTransporter, gstin);
    await service.getEWayBill(standalonePayloads.get, gstin);
    await service.generateConsolidatedEWayBill(standalonePayloads.consolidate, gstin);
    await service.getConsolidatedEWayBill(standalonePayloads.getConsolidated, gstin);
    await service.extendEWayBill(standalonePayloads.extend, gstin);
    await service.initiateMultiVehicleMovement(standalonePayloads.initiate, gstin);
    await service.addMultiVehicles(standalonePayloads.add, gstin);
    await service.changeMultiVehicles(standalonePayloads.change, gstin);
    await service.closeEWayBill(standalonePayloads.close, gstin);
    await service.getTransporterView({ date: '2024-01-02', gstin });
    await service.getTransporterStateView({ date: '2024-01-02', gstin, state_code: '07' });
    await service.getTransporterGstinView({ date: '2024-01-02', gstin, gen_gstin: gstin });

    expect(fetcher.mock.calls.map(([url]) => url)).toEqual([
      `${config.baseUrl}/geteinv/`,
      `${config.ewayBillBaseUrl}/generate/`,
      `${config.ewayBillBaseUrl}/cancel/`,
      `${config.ewayBillBaseUrl}/update-partb/`,
      `${config.ewayBillBaseUrl}/update-transporter/`,
      `${config.ewayBillBaseUrl}/getewb/`,
      `${config.ewayBillBaseUrl}/consolidate/`,
      `${config.ewayBillBaseUrl}/get-consolidated/`,
      `${config.ewayBillBaseUrl}/extend/`,
      `${config.ewayBillBaseUrl}/initiate-multi-vehicle-movement/`,
      `${config.ewayBillBaseUrl}/add-multi-vehicles/`,
      `${config.ewayBillBaseUrl}/change-multi-vehicles/`,
      `${config.ewayBillBaseUrl}/closure/`,
      `${config.ewayBillBaseUrl}/get-ewb-transporter-view/?date=2024-01-02&gstin=${gstin}`,
      `${config.ewayBillBaseUrl}/get-ewb-transporter-state-view/?date=2024-01-02&gstin=${gstin}&state_code=07`,
      `${config.ewayBillBaseUrl}/get-ewb-transporter-gstin-view/?date=2024-01-02&gstin=${gstin}&gen_gstin=${gstin}`,
    ]);

    for (const [, request] of fetcher.mock.calls.slice(1, 13)) {
      expect(request?.headers).toMatchObject({
        Token: config.token,
        gstin,
      });
    }
    expect(fetcher.mock.calls.slice(13).every(([, request]) => request?.method === 'GET')).toBe(true);
  });

  it('rejects incomplete standalone E-Way Bill payloads before GSTZen', async () => {
    const fetcher = vi.fn();
    const service = await createService(fetcher);
    const gstin = '29AAFCC9980M1ZR';

    expect(() => service.createEWayBill({}, gstin)).toThrow(
      'GSTZEN_INVALID_EWAY_BILL_CREATE_PAYLOAD',
    );
    expect(() => service.updateEWayBillPartB({ ewbNo: 111000609282 }, gstin)).toThrow(
      'GSTZEN_INVALID_EWAY_BILL_UPDATEPARTB_PAYLOAD',
    );
    expect(() => service.extendEWayBill({ ewbNo: 191010282840 }, gstin)).toThrow(
      'GSTZEN_INVALID_EWAY_BILL_EXTEND_PAYLOAD',
    );
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('gets an e-invoice by a validated IRN using the published HTTP contract', async () => {
    const fetcher = vi.fn().mockImplementation(async () =>
      new Response(JSON.stringify({ status: 1, Irn: 'a'.repeat(64) }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
    const service = await createService(fetcher);
    const payload = {
      SellerDtls: { Gstin: '29AADCG4992P1ZP' },
      Irn: 'a'.repeat(64),
    };
    const nic1Payload = { ...payload, irp: 'NIC1' };

    await service.getEInvoice(payload);
    await service.getEInvoice(nic1Payload);

    expect(fetcher).toHaveBeenNthCalledWith(
      1,
      `${config.baseUrl}/geteinv/`,
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          Accept: 'application/json',
          'Content-Type': 'application/json',
          Token: config.token,
        }),
        body: JSON.stringify(payload),
      }),
    );
    expect(fetcher).toHaveBeenNthCalledWith(
      2,
      `${config.baseUrl}/geteinv/`,
      expect.objectContaining({ body: JSON.stringify(nic1Payload) }),
    );

    await expect(service.getEInvoice({ Irn: 'invalid' })).rejects.toThrow(
      'GSTZEN_INVALID_GET_EINVOICE_PAYLOAD',
    );
    await expect(
      service.getEInvoice({ SellerDtls: { Gstin: 'invalid' }, Irn: 'a'.repeat(64) }),
    ).rejects.toThrow('GSTZEN_INVALID_GET_EINVOICE_PAYLOAD');
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('validates generate e-invoice payloads with optional complete EwbDtls', async () => {
    const fetcher = vi.fn().mockImplementation(async () =>
      new Response(JSON.stringify({ status: 1 }), { status: 200 }),
    );
    const service = await createService(fetcher);

    await service.generateEInvoice(validEInvoicePayload);
    await service.generateEInvoice({
      ...validEInvoicePayload,
      EwbDtls: {
        TransId: '21ADAPP6261D1Z1',
        TransName: 'Just in time Shippers Pvt Limited',
        TransMode: '1',
        Distance: 0,
        VehNo: 'KA331234',
        VehType: 'R',
      },
    });

    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('validates the complete generate E-Way Bill on IRN payload', async () => {
    const fetcher = vi.fn().mockImplementation(async () =>
      new Response(JSON.stringify({ status: 1 }), { status: 200 }),
    );
    const service = await createService(fetcher);

    await service.generateEWayBill(validEWayBillOnIrnPayload);

    const sent = JSON.parse(fetcher.mock.calls[0][1]?.body as string);
    expect(sent.ItemList[0].ItemNo).toBe(0);
    expect(sent.ExpShipDtls.TrdNm).toBe('ABC');

    await expect(service.generateEWayBill(validEInvoicePayload)).rejects.toThrow(
      'GSTZEN_INVALID_EWAY_BILL_ON_IRN_PAYLOAD',
    );
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('validates the complete cancel E-Way Bill on IRN payload', async () => {
    const fetcher = vi.fn().mockImplementation(async () =>
      new Response(JSON.stringify({ status: 1 }), { status: 200 }),
    );
    const service = await createService(fetcher);

    await service.cancelEWayBill(validCancelEWayBillOnIrnPayload);

    const sent = JSON.parse(fetcher.mock.calls[0][1]?.body as string);
    expect(sent.ItemList[0].ItemNo).toBe(0);
    expect(sent.ShipDtls.Gstin).toBe('URP');
    expect(sent).not.toHaveProperty('EwbDtls');

    await expect(service.cancelEWayBill({ Irn: 'incomplete' })).rejects.toThrow(
      'GSTZEN_INVALID_CANCEL_EWAY_BILL_ON_IRN_PAYLOAD',
    );
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('accepts official optional sections and schema-minimal fields', async () => {
    const fetcher = vi.fn().mockImplementation(async () =>
      new Response(JSON.stringify({ status: 1 }), { status: 200 }),
    );
    const service = await createService(fetcher);
    const minimal = {
      ...validEInvoicePayload,
      TranDtls: { TaxSch: 'GST', SupTyp: 'SEZWP' },
      BuyerDtls: {
        Gstin: 'URP',
        LglNm: 'Export Customer',
        Pos: '96',
        Addr1: 'Overseas address',
        Loc: 'Dubai',
        Stcd: '96',
      },
      ItemList: [
        {
          SlNo: '1',
          IsServc: 'Y',
          HsnCd: '998311',
          UnitPrice: 1000,
          TotAmt: 1000,
          AssAmt: 1000,
          GstRt: 18,
          TotItemVal: 1180,
          BchDtls: { Nm: 'BATCH-1', ExpDt: '31/12/2026' },
          AttribDtls: [{ Nm: 'Plan', Val: 'Annual' }],
        },
      ],
      ValDtls: { AssVal: 1000, TotInvVal: 1180 },
      DispDtls: {
        Nm: 'Dispatch Depot',
        Addr1: 'Warehouse Road',
        Loc: 'Bengaluru',
        Pin: 560077,
        Stcd: '29',
      },
      ShipDtls: {
        Gstin: 'URP',
        LglNm: 'Export Customer',
        Addr1: 'Port Road',
        Loc: 'Mumbai',
        Pin: 400001,
        Stcd: '27',
      },
      PayDtls: { Nm: 'GSTZEN DEMO PRIVATE LIMITED', CrDay: 30 },
      RefDtls: { InvRm: 'Annual software service' },
      ExpDtls: { Port: 'INBOM4', RefClm: 'N', CntCode: 'AE' },
      EwbDtls: { Distance: 120 },
    };

    await service.generateEInvoice(minimal);

    expect(fetcher).toHaveBeenCalledOnce();
  });

  it('rejects invalid GST identity and incomplete EwbDtls before calling GSTZen', async () => {
    const fetcher = vi.fn();
    const service = await createService(fetcher);

    await expect(
      service.generateEInvoice({
        ...validEInvoicePayload,
        SellerDtls: { ...validEInvoicePayload.SellerDtls, Gstin: 'INVALID' },
      }),
    ).rejects.toThrow('GSTZEN_INVALID_EINVOICE_PAYLOAD');
    await expect(
      service.generateEInvoice({
        ...validEInvoicePayload,
        EwbDtls: { TransMode: '1' },
      }),
    ).rejects.toThrow('GSTZEN_INVALID_EINVOICE_PAYLOAD');
    await expect(
      service.generateEInvoice({
        ...validEInvoicePayload,
        DocDtls: { ...validEInvoicePayload.DocDtls, No: '12345678901234567' },
      }),
    ).rejects.toThrow('GSTZEN_INVALID_EINVOICE_PAYLOAD');
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('rejects GSTZen status zero responses even when HTTP succeeds', async () => {
    const fetcher = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({ status: 0, message: 'GSTIN is not activated' }),
        { status: 200 },
      ),
    );
    const service = await createService(fetcher);

    await expect(service.generateEInvoice(validEInvoicePayload)).rejects.toThrow(
      'GSTZEN_REQUEST_FAILED:GSTIN is not activated',
    );
  });
});