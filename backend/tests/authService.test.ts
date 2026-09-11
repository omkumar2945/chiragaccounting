import { beforeAll, describe, expect, it } from 'vitest';

import type {
  AuthRepository,
  AuthUserRecord,
} from '../src/services/authService.js';

process.env.JWT_SECRET = 'unit-test-secret-unit-test-secret';
process.env.MSSQL_SERVER = 'localhost';
process.env.MSSQL_DATABASE = 'unit-test';
process.env.MSSQL_USER = 'unit-test';
process.env.MSSQL_PASSWORD = 'unit-test';

let AuthService: typeof import('../src/services/authService.js').AuthService;
let hashPassword: typeof import('../src/services/authService.js').hashPassword;

beforeAll(async () => {
  const module = await import('../src/services/authService.js');
  AuthService = module.AuthService;
  hashPassword = module.hashPassword;
});

describe('AuthService', () => {
  it('returns the Flutter auth contract for a valid super-admin login', async () => {
    const repository = await fakeRepository();
    const result = await new AuthService(repository).login({
      identifier: 'ADMIN@EXAMPLE.COM',
      password: 'Correct#Password9',
      userType: 'staff',
    });

    expect(result.user).toMatchObject({
      id: 'admin-1',
      role: 'super_admin',
      firmId: 'tenant-1',
      isActive: true,
    });
    expect(result.token.accessToken.split('.')).toHaveLength(3);
    expect(result.token.refreshToken).not.toBe('');
    expect(repository.recordSuccessfulLogin).toHaveBeenCalledWith('admin-1');
  });

  it('does not authenticate staff through the client login mode', async () => {
    const repository = await fakeRepository();
    await expect(new AuthService(repository).login({
      identifier: 'admin@example.com',
      password: 'Correct#Password9',
      userType: 'client',
    })).rejects.toThrow('Invalid email/mobile or password.');
  });

  it('issues a session only after Firebase has verified a registered mobile', async () => {
    const repository = await fakeRepository();
    const result = await new AuthService(repository).loginWithVerifiedMobile({
      mobile: '+91 98765 43210',
      userType: 'staff',
    });

    expect(result.user.id).toBe('admin-1');
    expect(repository.recordSuccessfulLogin).toHaveBeenCalledWith('admin-1');
  });

  it('does not authorize a Firebase-verified mobile through the wrong login mode', async () => {
    const repository = await fakeRepository();
    await expect(new AuthService(repository).loginWithVerifiedMobile({
      mobile: '+919876543210',
      userType: 'client',
    })).rejects.toThrow('This mobile number is not authorized for this login.');
  });

  it('rotates a refresh token and rejects its reuse', async () => {
    const repository = await fakeRepository();
    const service = new AuthService(repository);
    const login = await service.login({
      identifier: '9876543210',
      password: 'Correct#Password9',
      userType: 'staff',
    });

    const refreshed = await service.refresh(login.token.refreshToken);
    expect(refreshed.token.refreshToken).not.toBe(login.token.refreshToken);
    await expect(service.refresh(login.token.refreshToken)).rejects.toThrow(
      'Invalid or expired refresh token.',
    );
  });
});

async function fakeRepository() {
  const user: AuthUserRecord = {
    id: 'admin-1',
    name: 'Production Admin',
    email: 'admin@example.com',
    mobile: '9876543210',
    role: 'super_admin',
    tenantId: 'tenant-1',
    companyId: 'company-1',
    branchId: 'branch-1',
    firmName: 'Chirag Accounting',
    passwordHash: await hashPassword('Correct#Password9'),
    isActive: true,
    mustChangePassword: true,
    createdAt: new Date('2026-09-06T00:00:00.000Z'),
    lastLoginAt: null,
  };
  const refreshTokens = new Map<string, string>();
  const { vi } = await import('vitest');
  return {
    findUserByIdentifier: vi.fn(async (identifier: string) =>
      identifier === user.email || identifier === user.mobile ? user : null),
    findUserById: vi.fn(async (userId: string) => userId === user.id ? user : null),
    recordSuccessfulLogin: vi.fn(async () => undefined),
    markEmailVerified: vi.fn(async () => undefined),
    updatePassword: vi.fn(async () => undefined),
    saveRefreshToken: vi.fn(async (input) => {
      refreshTokens.set(input.tokenHash, input.userId);
    }),
    consumeRefreshToken: vi.fn(async (tokenHash: string) => {
      const userId = refreshTokens.get(tokenHash) ?? null;
      refreshTokens.delete(tokenHash);
      return userId;
    }),
  } satisfies AuthRepository;
}