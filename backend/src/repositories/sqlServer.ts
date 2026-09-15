import sql from 'mssql';

import { env } from '../config/env.js';

let poolPromise: Promise<sql.ConnectionPool> | null = null;

export function getSqlPool() {
  if (poolPromise == null) {
    if (!env.MSSQL_SERVER || !env.MSSQL_DATABASE || !env.MSSQL_USER || !env.MSSQL_PASSWORD) {
      throw new Error('SQL Server is not configured. Use the MySQL-backed API routes for this deployment.');
    }
    poolPromise = sql.connect({
      server: env.MSSQL_SERVER,
      port: env.MSSQL_PORT,
      database: env.MSSQL_DATABASE,
      user: env.MSSQL_USER,
      password: env.MSSQL_PASSWORD,
      options: {
        encrypt: env.MSSQL_ENCRYPT,
        trustServerCertificate: env.MSSQL_TRUST_CERT,
      },
      pool: {
        min: 0,
        max: 12,
        idleTimeoutMillis: 30000,
      },
    });
  }
  return poolPromise;
}
