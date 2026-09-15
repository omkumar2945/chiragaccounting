import { describe, expect, it } from 'vitest';

import { clientCredentialActionSchema } from '../src/routes/clientDataRoutes.js';
import { isValidPassword } from '../src/security/passwordPolicy.js';
import { generateTemporaryPassword } from '../src/security/temporaryPassword.js';

describe('temporary password generation', () => {
  it('creates a policy-compliant password without predictable character groups', () => {
    const password = generateTemporaryPassword();

    expect(password).toHaveLength(12);
    expect(isValidPassword(password)).toBe(true);
  });

  it('rejects an unsafe configured length', () => {
    expect(() => generateTemporaryPassword(7)).toThrow(
      'Temporary password length must be at least eight characters.',
    );
  });

  it('accepts only explicit onboarding and reset actions', () => {
    expect(clientCredentialActionSchema.parse({ action: 'onboard' })).toEqual({
      action: 'onboard',
    });
    expect(clientCredentialActionSchema.parse({ action: 'reset' })).toEqual({
      action: 'reset',
    });
    expect(clientCredentialActionSchema.safeParse({}).success).toBe(false);
    expect(
      clientCredentialActionSchema.safeParse({ action: 'generate' }).success,
    ).toBe(false);
  });
});