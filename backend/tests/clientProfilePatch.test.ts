import { describe, expect, it } from 'vitest';

import { clientProfilePatchSchema } from '../src/services/clientProfilePatch.js';

describe('client profile patch validation', () => {
  it('keeps a partial update limited to the explicitly supplied field', () => {
    const result = clientProfilePatchSchema.parse({ city: 'Bengaluru' });

    expect(result).toEqual({ city: 'Bengaluru', clearFields: [] });
    expect(result).not.toHaveProperty('gstin');
  });

  it('rejects an empty field unless the request explicitly clears it', () => {
    const result = clientProfilePatchSchema.safeParse({ gstin: '' });

    expect(result.success).toBe(false);
  });

  it('allows an explicit clear without substituting defaults for other fields', () => {
    const result = clientProfilePatchSchema.parse({ clearFields: ['gstin'] });

    expect(result).toEqual({ clearFields: ['gstin'] });
  });

  it('rejects a request that both supplies and clears the same field', () => {
    const result = clientProfilePatchSchema.safeParse({
      gstin: '29ABCDE1234F1Z5',
      clearFields: ['gstin'],
    });

    expect(result.success).toBe(false);
  });
});