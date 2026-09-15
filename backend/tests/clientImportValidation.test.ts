import { describe, expect, it } from 'vitest';

import {
  decideImportIdentity,
  parseImportedClient,
} from '../src/services/clientImportValidation.js';

describe('client import identity validation', () => {
  it('normalizes a valid client row before it reaches the database', () => {
    const result = parseImportedClient({
      name: '  Client ABC  ',
      email: 'CLIENT@EXAMPLE.COM ',
      mobile: '+91 98765 43210',
      companyName: 'ABC Traders',
      gstin: '29abcde1234f1z5',
    });

    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(result.data).toMatchObject({
      name: 'Client ABC',
      email: 'client@example.com',
      mobile: '9876543210',
      firmName: 'ABC Traders',
      gstin: '29ABCDE1234F1Z5',
      sourceRecordId: 'client@example.com:9876543210',
    });
  });

  it('allows an update only when email and mobile match the same client identity', () => {
    const result = parseImportedClient({
      name: 'Client ABC',
      email: 'client@example.com',
      mobile: '9876543210',
    });

    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(decideImportIdentity(result.data, [{
      id: 42,
      email: 'client@example.com',
      mobile: '9876543210',
      role: 'client',
    }])).toEqual({ action: 'update', userId: 42 });
  });

  it('rejects a row when only one identity field matches an existing client', () => {
    const result = parseImportedClient({
      name: 'Client ABC',
      email: 'client@example.com',
      mobile: '9999999999',
    });

    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(decideImportIdentity(result.data, [{
      id: 42,
      email: 'client@example.com',
      mobile: '9876543210',
      role: 'client',
    }])).toMatchObject({ action: 'conflict' });
  });

  it('rejects an email and mobile that resolve to two different existing accounts', () => {
    const result = parseImportedClient({
      name: 'Client ABC',
      email: 'client@example.com',
      mobile: '9876543210',
    });

    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(decideImportIdentity(result.data, [
      { id: 42, email: 'client@example.com', mobile: '1111111111', role: 'client' },
      { id: 43, email: 'other@example.com', mobile: '9876543210', role: 'client' },
    ])).toMatchObject({ action: 'conflict' });
  });

  it('never converts an existing Admin identity into an imported Client', () => {
    const result = parseImportedClient({
      name: 'Existing Admin',
      email: 'admin@example.com',
      mobile: '9876543210',
    });

    expect(result.success).toBe(true);
    if (!result.success) return;
    expect(decideImportIdentity(result.data, [{
      id: 1,
      email: 'admin@example.com',
      mobile: '9876543210',
      role: 'super_admin',
    }])).toEqual({
      action: 'conflict',
      reason: 'The matching identity belongs to a non-client account.',
    });
  });
});