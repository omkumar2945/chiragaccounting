import { afterEach, describe, expect, it, vi } from 'vitest';

describe('LocationService', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('maps provider state and district to stable standardized IDs', async () => {
    process.env.JWT_SECRET = 'unit-test-secret-unit-test-secret';
    process.env.MSSQL_SERVER = 'localhost';
    process.env.MSSQL_DATABASE = 'unit-test';
    process.env.MSSQL_USER = 'unit-test';
    process.env.MSSQL_PASSWORD = 'unit-test';
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: async () => [{
        PostOffice: [{
          Name: 'Bengaluru GPO',
          District: 'Bengaluru Urban',
          State: 'Karnataka',
        }],
      }],
    }));

    const { LocationService } = await import(
      '../src/services/location/locationService.js'
    );
    const locations = await new LocationService().lookupIndianPincode('560001');

    expect(locations).toHaveLength(1);
    expect(locations[0]).toMatchObject({
      countryId: 'IN',
      stateId: '29',
      stateName: 'Karnataka',
      cityId: 'BENGALURU-URBAN',
      cityName: 'Bengaluru Urban',
      pincode: '560001',
    });
  });
});