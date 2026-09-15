import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import type { Request, Response } from 'express';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

const { execute, getConnection, verifyIdToken, deliverEmailOtp } = vi.hoisted(() => ({
  execute: vi.fn(),
  getConnection: vi.fn(),
  verifyIdToken: vi.fn(),
  deliverEmailOtp: vi.fn(),
}));

vi.mock('../src/database.js', () => ({
  default: { execute, getConnection },
}));
vi.mock('firebase-admin/app', () => ({
  cert: vi.fn(),
  getApps: vi.fn(() => [{}]),
  initializeApp: vi.fn(),
}));
vi.mock('firebase-admin/auth', () => ({
  getAuth: vi.fn(() => ({ verifyIdToken })),
}));
vi.mock('../src/services/clientDataAudit.js', () => ({
  recordClientDataChange: vi.fn(),
}));
vi.mock('../src/services/emailOtpService.js', () => ({
  EmailDeliveryConfigurationError: class EmailDeliveryConfigurationError extends Error {},
  deliverEmailOtp,
}));

process.env.JWT_SECRET = 'unit-test-secret-unit-test-secret';
process.env.DB_HOST = 'localhost';
process.env.DB_USER = 'unit-test';
process.env.DB_PASSWORD = 'unit-test';
process.env.DB_NAME = 'unit-test';

let login: typeof import('../src/controllers/authController.js').login;
let loginWithFirebasePhone: typeof import('../src/controllers/authController.js').loginWithFirebasePhone;
let refreshToken: typeof import('../src/controllers/authController.js').refreshToken;
let forgotPassword: typeof import('../src/controllers/authController.js').forgotPassword;
let verifyPasswordResetOtp: typeof import('../src/controllers/authController.js').verifyPasswordResetOtp;
let resetPassword: typeof import('../src/controllers/authController.js').resetPassword;
let authRouter: {
  stack: Array<{
    route?: { path?: string; stack: Array<{ handle: unknown }> };
  }>;
};

beforeAll(async () => {
  ({
    login,
    loginWithFirebasePhone,
    refreshToken,
    forgotPassword,
    verifyPasswordResetOtp,
    resetPassword,
  } = await import('../src/controllers/authController.js'));
  const { default: router } = await import('../src/routes/auth.js');
  authRouter = router as unknown as typeof authRouter;
});

beforeEach(() => {
  execute.mockReset();
  getConnection.mockReset();
  verifyIdToken.mockReset();
  deliverEmailOtp.mockReset();
});

describe.each([
  ['disabled', { login_enabled: 0, account_locked: 0 }],
  ['locked', { login_enabled: 1, account_locked: 1 }],
])('a %s client account', (_description, policy) => {
  it('does not issue a password session', async () => {
    execute.mockResolvedValueOnce([[await clientUser(policy)]]);
    const response = createResponse();

    await login({ body: { identifier: 'client@example.com', password: 'Correct#Password9' } } as Request, response as unknown as Response);

    expect(response.status).toHaveBeenCalledWith(401);
    expect(getConnection).not.toHaveBeenCalled();
  });

  it('does not issue a Firebase phone session', async () => {
    execute.mockResolvedValueOnce([[await clientUser(policy)]]);
    verifyIdToken.mockResolvedValueOnce({ phone_number: '+91 98765 43210', email_verified: false });
    const response = createResponse();

    await loginWithFirebasePhone({ body: { idToken: 'verified-token', userType: 'client' } } as Request, response as unknown as Response);

    expect(response.status).toHaveBeenCalledWith(401);
    expect(getConnection).not.toHaveBeenCalled();
  });

  it('does not refresh an existing session', async () => {
    execute.mockResolvedValueOnce([[await clientUser(policy)]]);
    const response = createResponse();
    const token = jwt.sign({ id: 42, type: 'refresh' }, process.env.JWT_SECRET!);

    await refreshToken({ body: { refreshToken: token } } as Request, response as unknown as Response);

    expect(response.status).toHaveBeenCalledWith(401);
    expect(getConnection).not.toHaveBeenCalled();
  });
});

describe('public password reset', () => {
  it('registers reset endpoints without JWT middleware', () => {
    for (const [path, handler] of [
      ['/auth/forgot-password', forgotPassword],
      ['/auth/verify-otp', verifyPasswordResetOtp],
      ['/auth/reset-password', resetPassword],
    ] as const) {
      const route = authRouter.stack.find((layer) => layer.route?.path === path)?.route;
      expect(route?.stack).toHaveLength(1);
      expect(route?.stack[0]?.handle).toBe(handler);
    }
  });

  it('issues a one-time reset authorization without a signed-in user', async () => {
    execute.mockResolvedValueOnce([[{ id: 42, email: 'client@example.com' }]]);
    deliverEmailOtp.mockResolvedValueOnce(undefined);
    const forgotResponse = createResponse();

    await forgotPassword(
      { body: { identifier: 'client@example.com' } } as Request,
      forgotResponse as unknown as Response,
    );

    expect(forgotResponse.status).toHaveBeenCalledWith(202);
    expect(deliverEmailOtp).toHaveBeenCalledOnce();
    const forgotPayload = forgotResponse.json.mock.calls[0]?.[0] as {
      challengeId: string;
    };
    const otp = String(deliverEmailOtp.mock.calls[0]?.[1] ?? '');
    expect(forgotPayload.challengeId).toMatch(/^[A-Za-z0-9_-]{32,}$/);
    expect(otp).toMatch(/^\d{6}$/);

    const verificationResponse = createResponse();
    verifyPasswordResetOtp(
      { body: { challengeId: forgotPayload.challengeId, otp } } as Request,
      verificationResponse as unknown as Response,
    );
    const verificationPayload = verificationResponse.json.mock.calls[0]?.[0] as {
      resetToken: string;
    };
    expect(verificationPayload.resetToken).toMatch(/^[A-Za-z0-9_-]{32,}$/);

    const connection = {
      beginTransaction: vi.fn().mockResolvedValue(undefined),
      execute: vi
        .fn()
        .mockResolvedValueOnce([[{ id: 42, role: 'client' }]])
        .mockResolvedValueOnce([{ affectedRows: 1 }]),
      commit: vi.fn().mockResolvedValue(undefined),
      rollback: vi.fn().mockResolvedValue(undefined),
      release: vi.fn(),
    };
    getConnection.mockResolvedValueOnce(connection);
    const resetResponse = createResponse();
    const newPassword = 'New#Password9';

    await resetPassword(
      { body: { resetToken: verificationPayload.resetToken, newPassword } } as Request,
      resetResponse as unknown as Response,
    );

    expect(resetResponse.status).toHaveBeenCalledWith(204);
    const updateParameters = connection.execute.mock.calls[1]?.[1] as unknown[];
    expect(await bcrypt.compare(newPassword, String(updateParameters[0]))).toBe(true);
  });

  it('returns the same generic response for unknown users and delivery failures', async () => {
    execute.mockResolvedValueOnce([[]]);
    const unknownResponse = createResponse();
    await forgotPassword(
      { body: { identifier: 'unknown@example.com' } } as Request,
      unknownResponse as unknown as Response,
    );

    execute.mockResolvedValueOnce([[{ id: 42, email: 'client@example.com' }]]);
    deliverEmailOtp.mockRejectedValueOnce(new Error('SMTP unavailable'));
    const deliveryFailureResponse = createResponse();
    await forgotPassword(
      { body: { identifier: 'client@example.com' } } as Request,
      deliveryFailureResponse as unknown as Response,
    );

    expect(unknownResponse.status).toHaveBeenCalledWith(202);
    expect(deliveryFailureResponse.status).toHaveBeenCalledWith(202);
    expect(unknownResponse.json.mock.calls[0]?.[0]?.message).toBe(
      deliveryFailureResponse.json.mock.calls[0]?.[0]?.message,
    );
  });
});

function createResponse() {
  const response = {
    status: vi.fn(),
    json: vi.fn(),
    send: vi.fn(),
  };
  response.status.mockReturnValue(response);
  return response;
}

async function clientUser(policy: { login_enabled: number; account_locked: number }) {
  return {
    id: 42,
    name: 'Restricted Client',
    email: 'client@example.com',
    mobile: '9876543210',
    firm_name: 'Chirag Accounting',
    password_hash: await bcrypt.hash('Correct#Password9', 4),
    role: 'client',
    account_origin: 'imported',
    client_status: 'active',
    login_status: 'active',
    is_active: 1,
    must_change_password: 0,
    created_at: new Date('2026-09-14T00:00:00.000Z'),
    last_login_at: null,
    ...policy,
  };
}