import { env } from '../../config/env.js';

export interface StandardLocation {
  countryId: string;
  countryName: string;
  stateId: string;
  stateName: string;
  cityId: string;
  cityName: string;
  district: string;
  pincode: string;
  locality: string;
  postOffice: string;
  source: string;
}

interface CacheEntry {
  expiresAt: number;
  locations: StandardLocation[];
}

const cache = new Map<string, CacheEntry>();
const cacheTtlMs = 7 * 24 * 60 * 60 * 1000;
const indianStateIds: Record<string, string> = {
  'jammu and kashmir': '01', 'himachal pradesh': '02', punjab: '03', chandigarh: '04',
  uttarakhand: '05', haryana: '06', delhi: '07', rajasthan: '08', 'uttar pradesh': '09',
  bihar: '10', sikkim: '11', 'arunachal pradesh': '12', nagaland: '13', manipur: '14',
  mizoram: '15', tripura: '16', meghalaya: '17', assam: '18', 'west bengal': '19',
  jharkhand: '20', odisha: '21', chhattisgarh: '22', 'madhya pradesh': '23', gujarat: '24',
  'dadra and nagar haveli and daman and diu': '26', maharashtra: '27',
  'andhra pradesh': '37', karnataka: '29', goa: '30', lakshadweep: '31', kerala: '32',
  'tamil nadu': '33', puducherry: '34', 'andaman and nicobar islands': '35',
  telangana: '36', ladakh: '38',
};

function locationId(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/[^A-Za-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .toUpperCase();
}

export class LocationService {
  async lookupIndianPincode(pincode: string): Promise<StandardLocation[]> {
    if (!/^\d{6}$/.test(pincode)) {
      throw new Error('Indian pincode must contain 6 digits.');
    }

    const cached = cache.get(pincode);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.locations;
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);
    try {
      const baseUrl = (env.LOCATION_API_URL || 'https://api.postalpincode.in/pincode')
        .replace(/\/$/, '');
      const response = await fetch(`${baseUrl}/${encodeURIComponent(pincode)}`, {
        signal: controller.signal,
        headers: {
          Accept: 'application/json',
          ...(env.LOCATION_API_KEY
            ? { Authorization: `Bearer ${env.LOCATION_API_KEY}` }
            : {}),
        },
      });
      if (!response.ok) {
        throw new Error(`Location provider returned ${response.status}.`);
      }
      const payload: unknown = await response.json();
      const offices = this.extractOffices(payload);
      const locations = offices
        .map((office) => this.mapOffice(office, pincode))
        .filter((location): location is StandardLocation => location !== null);
      cache.set(pincode, {
        expiresAt: Date.now() + cacheTtlMs,
        locations,
      });
      return locations;
    } finally {
      clearTimeout(timeout);
    }
  }

  private extractOffices(payload: unknown): Record<string, unknown>[] {
    if (!Array.isArray(payload) || payload.length === 0) return [];
    const envelope = payload[0];
    if (!envelope || typeof envelope !== 'object') return [];
    const raw = (envelope as Record<string, unknown>).PostOffice;
    return Array.isArray(raw)
      ? raw.filter(
          (office): office is Record<string, unknown> =>
            office !== null && typeof office === 'object',
        )
      : [];
  }

  private mapOffice(
    office: Record<string, unknown>,
    pincode: string,
  ): StandardLocation | null {
    const text = (key: string) => String(office[key] ?? '').trim();
    const stateName = text('State');
    const district = text('District');
    const postOffice = text('Name');
    if (!stateName || (!district && !postOffice)) return null;
    return {
      countryId: 'IN',
      countryName: 'India',
      stateId: indianStateIds[stateName.toLowerCase()] ?? '',
      stateName,
      cityId: locationId(district || postOffice),
      cityName: district || postOffice,
      district,
      pincode,
      locality: postOffice,
      postOffice,
      source: 'location-api',
    };
  }
}