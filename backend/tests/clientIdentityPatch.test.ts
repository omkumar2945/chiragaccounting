import { describe, expect, it } from 'vitest';

import { clientIdentityPatchSchema } from '../src/routes/clientDataRoutes.js';

describe('client identity patch validation', () => {
  it('normalizes mobile and email values before an identity update reaches MySQL', () => {
    const result = clientIdentityPatchSchema.parse({
      email: ' CLIENT@EXAMPLE.COM ',
      mobile: '+91 98765 43210',
      ifMatchVersion: 3,
    });

    expect(result).toEqual({
      email: 'client@example.com',
      mobile: '9876543210',
      ifMatchVersion: 3,
    });
  });

  it('rejects an identity update with no changed field', () => {
    expect(clientIdentityPatchSchema.safeParse({ ifMatchVersion: 3 }).success).toBe(false);
  });

  it('accepts explicit client lifecycle changes', () => {
    const result = clientIdentityPatchSchema.parse({
      isActive: false,
      clientStatus: 'archived',
      loginStatus: 'locked',
      ifMatchVersion: 4,
    });

    expect(result).toMatchObject({
      isActive: false,
      clientStatus: 'archived',
      loginStatus: 'locked',
    });
  });
});