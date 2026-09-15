import type { Request, Response } from 'express';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

const { getConnection, recordClientDataChange } = vi.hoisted(() => ({
  getConnection: vi.fn(),
  recordClientDataChange: vi.fn(),
}));

vi.mock('../src/database.js', () => ({
  default: { getConnection },
}));
vi.mock('../src/services/clientDataAudit.js', () => ({
  recordClientDataChange,
}));

process.env.JWT_SECRET = 'unit-test-secret-unit-test-secret';
process.env.DB_HOST = 'localhost';
process.env.DB_USER = 'unit-test';
process.env.DB_PASSWORD = 'unit-test';
process.env.DB_NAME = 'unit-test';

let register: typeof import('../src/controllers/authController.js').register;

beforeAll(async () => {
  ({ register } = await import('../src/controllers/authController.js'));
});

beforeEach(() => {
  getConnection.mockReset();
  recordClientDataChange.mockReset();
  recordClientDataChange.mockResolvedValue(undefined);
});

describe('self-registration', () => {
  it('creates a pending authoritative client that the admin directory can load', async () => {
    const connection = createConnection();
    connection.execute
      .mockResolvedValueOnce([[], []])
      .mockResolvedValueOnce([{ insertId: 73 }, []])
      .mockResolvedValue([{}, []]);
    getConnection.mockResolvedValue(connection);
    const response = createResponse();

    await register({
      body: {
        name: 'Asha Singh',
        email: 'ASHA@EXAMPLE.COM',
        mobile: '+91 98765 43210',
        password: 'Correct#Password9',
        firmName: 'Asha Traders',
        role: 'client',
        gstin: '29ABCDE1234F1Z5',
        pan: 'ABCDE1234F',
        state: 'Karnataka',
        city: 'Bengaluru',
      },
    } as Request, response as unknown as Response);

    expect(connection.beginTransaction).toHaveBeenCalledOnce();
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO users'),
      expect.arrayContaining([
        'Asha Singh',
        'asha@example.com',
        '9876543210',
        'Asha Traders',
      ]),
    );
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining("'client', 'selfRegistered', 'pendingApproval', 'loginNotCreated', FALSE, FALSE"),
      expect.any(Array),
    );
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO client_profiles'),
      [73, 'Asha Traders', '29ABCDE1234F1Z5', 'ABCDE1234F', 'Karnataka', 'Bengaluru', 73, 73],
    );
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO client_compliance'),
      [73, 73, 73],
    );
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO client_access_policies'),
      [73, 73, 73],
    );
    expect(connection.execute).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO client_workspaces'),
      [73, 73, 73],
    );
    expect(recordClientDataChange).toHaveBeenCalledWith(
      connection,
      73,
      73,
      'client.selfRegistered',
      expect.objectContaining({ email: 'asha@example.com', mobile: '9876543210' }),
    );
    expect(connection.commit).toHaveBeenCalledOnce();
    expect(connection.release).toHaveBeenCalledOnce();
    expect(response.status).toHaveBeenCalledWith(201);
  });

  it('does not let a public registration request choose a staff role', async () => {
    const response = createResponse();

    await register({
      body: {
        name: 'Unapproved Staff',
        email: 'staff@example.com',
        mobile: '9876543210',
        password: 'Correct#Password9',
        firmName: 'Example Firm',
        role: 'super_admin',
      },
    } as Request, response as unknown as Response);

    expect(response.status).toHaveBeenCalledWith(400);
    expect(getConnection).not.toHaveBeenCalled();
  });
});

function createConnection() {
  return {
    beginTransaction: vi.fn().mockResolvedValue(undefined),
    commit: vi.fn().mockResolvedValue(undefined),
    rollback: vi.fn().mockResolvedValue(undefined),
    release: vi.fn(),
    execute: vi.fn(),
  };
}

function createResponse() {
  const response = {
    status: vi.fn(),
    json: vi.fn(),
  };
  response.status.mockReturnValue(response);
  return response;
}