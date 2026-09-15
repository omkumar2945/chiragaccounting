import { describe, expect, it } from 'vitest';

import { nextClientDataRevision } from '../src/services/clientDataConcurrency.js';

describe('client data optimistic concurrency', () => {
  it('creates a new record at revision one without a match version', () => {
    expect(nextClientDataRevision(null, undefined)).toBe(1);
  });

  it('increments an existing record only when the caller has its current revision', () => {
    expect(nextClientDataRevision(7, 7)).toBe(8);
  });

  it('rejects stale, missing, and impossible expected versions', () => {
    expect(() => nextClientDataRevision(7, 6)).toThrow('CLIENT_DATA_CONFLICT');
    expect(() => nextClientDataRevision(7, undefined)).toThrow('CLIENT_DATA_CONFLICT');
    expect(() => nextClientDataRevision(null, 1)).toThrow('CLIENT_DATA_CONFLICT');
  });
});