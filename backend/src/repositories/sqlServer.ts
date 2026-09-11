import sql from 'mssql';

import { env } from '../config/env.js';

let poolPromise: Promise<sql.ConnectionPool> | null = null;

export function getSqlPool() {
  if (poolPromise == null) {
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
