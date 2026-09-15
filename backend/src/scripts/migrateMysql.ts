import fs from 'node:fs/promises';
import type { RowDataPacket } from 'mysql2';

import pool from '../database.js';

const bundledSchemaUrl = new URL('../db/schema.mysql.sql', import.meta.url);
const sourceSchemaUrl = new URL('../../../src/db/schema.mysql.sql', import.meta.url);
const schema = await fs.readFile(bundledSchemaUrl, 'utf8').catch(() =>
  fs.readFile(sourceSchemaUrl, 'utf8'),
);

if (await usersTableExists()) await validateExistingUsersTable();

for (const statement of schema.split(';')) {
  const sql = statement.trim();
  if (sql) await pool.query(sql);
}

const requiredColumns = [
  'mobile VARCHAR(20) NULL',
  "firm_name VARCHAR(200) NOT NULL DEFAULT 'Chirag Accounting'",
  "account_origin VARCHAR(40) NOT NULL DEFAULT 'legacyUnknown'",
  "client_status VARCHAR(40) NOT NULL DEFAULT 'active'",
  "login_status VARCHAR(40) NOT NULL DEFAULT 'active'",
  'is_active BOOLEAN NOT NULL DEFAULT TRUE',
  'must_change_password BOOLEAN NOT NULL DEFAULT TRUE',
  'identity_revision BIGINT UNSIGNED NOT NULL DEFAULT 1',
  'last_login_at DATETIME NULL',
];

for (const definition of requiredColumns) {
  const column = definition.split(' ', 1)[0];
  const [rows] = await pool.query<(RowDataPacket & { count: number })[]>(
    `SELECT COUNT(*) AS count
     FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = ?`,
    [column],
  );
  if (rows[0].count === 0) await pool.query(`ALTER TABLE users ADD COLUMN ${definition}`);
}

await ensureSupportedUserRoleColumn();
await normalizeMissingMobileNumbers();
await ensureUniqueUserColumn('email', 'users_email_unique');
await ensureUniqueUserColumn('mobile', 'users_mobile_unique');
await reconcileLegacySelfRegistrations();

await pool.end();
console.log('MySQL schema migration complete.');

async function usersTableExists() {
  const [rows] = await pool.query<(RowDataPacket & { count: number })[]>(
    `SELECT COUNT(*) AS count
     FROM information_schema.tables
     WHERE table_schema = DATABASE() AND table_name = 'users'`,
  );
  return rows[0].count > 0;
}

async function validateExistingUsersTable() {
  const [rows] = await pool.query<Array<RowDataPacket & {
    columnName: string;
    columnType: string;
  }>>(
    `SELECT COLUMN_NAME AS columnName, COLUMN_TYPE AS columnType
     FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'users'`,
  );
  const columns = new Map(rows.map((row) => [row.columnName, row.columnType.toLowerCase()]));
  const requiredColumns = [
    'id',
    'name',
    'email',
    'mobile',
    'password_hash',
    'role',
    'created_at',
    'updated_at',
  ];
  const missingColumns = requiredColumns.filter((column) => !columns.has(column));
  if (missingColumns.length > 0) {
    throw new Error(`Existing users table is incompatible; missing: ${missingColumns.join(', ')}`);
  }
  if (columns.get('id') !== 'int') {
    throw new Error('Existing users.id must be a signed INT before applying this authority schema.');
  }
}

async function normalizeMissingMobileNumbers() {
  const [rows] = await pool.query<Array<RowDataPacket & { isNullable: 'YES' | 'NO' }>>(
    `SELECT IS_NULLABLE AS isNullable
     FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'mobile'`,
  );
  if (rows[0]?.isNullable !== 'YES') {
    await pool.query('ALTER TABLE users MODIFY COLUMN mobile VARCHAR(20) NULL');
  }
  await pool.query("UPDATE users SET mobile = NULL WHERE mobile IS NOT NULL AND TRIM(mobile) = ''");
}

async function ensureSupportedUserRoleColumn() {
  const [rows] = await pool.query<Array<RowDataPacket & {
    columnType: string;
    isNullable: 'YES' | 'NO';
  }>>(
    `SELECT COLUMN_TYPE AS columnType, IS_NULLABLE AS isNullable
     FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'role'`,
  );
  const column = rows[0];
  if (!column) throw new Error('Existing users table is incompatible; missing: role');
  if (column.columnType.toLowerCase() === 'varchar(40)' && column.isNullable === 'NO') return;

  await pool.query("UPDATE users SET role = 'user' WHERE role IS NULL");
  await pool.query("ALTER TABLE users MODIFY COLUMN role VARCHAR(40) NOT NULL DEFAULT 'user'");
}

async function ensureUniqueUserColumn(column: 'email' | 'mobile', indexName: string) {
  const [indexes] = await pool.query<Array<RowDataPacket & {
    indexName: string;
    nonUnique: number;
    columnsList: string;
  }>>(
    `SELECT INDEX_NAME AS indexName, NON_UNIQUE AS nonUnique,
            GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columnsList
     FROM information_schema.statistics
     WHERE table_schema = DATABASE() AND table_name = 'users'
     GROUP BY INDEX_NAME, NON_UNIQUE`,
  );
  const alreadyUnique = indexes.some(
    (index) => Number(index.nonUnique) === 0 && index.columnsList === column,
  );
  if (alreadyUnique) return;

  const [duplicates] = await pool.query<(RowDataPacket & { count: number })[]>(
    `SELECT COUNT(*) AS count
     FROM (
       SELECT ${column}
       FROM users
       WHERE ${column} IS NOT NULL
       GROUP BY ${column}
       HAVING COUNT(*) > 1
     ) duplicate_values`,
  );
  if (duplicates[0].count > 0) {
    throw new Error(`Cannot add a unique users.${column} index while duplicate values exist.`);
  }
  await pool.query(`ALTER TABLE users ADD UNIQUE KEY ${indexName} (${column})`);
}

async function reconcileLegacySelfRegistrations() {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [rows] = await connection.execute<Array<RowDataPacket & {
      id: number;
      firmName: string;
    }>>(
      `SELECT id, firm_name AS firmName
       FROM users
       WHERE (
           (role = 'user'
            AND account_origin = 'legacyUnknown'
            AND client_status = 'active'
            AND login_status = 'active'
            AND is_active = TRUE)
           OR (role = ''
               AND account_origin = 'selfRegistered'
               AND client_status = 'pendingApproval'
               AND login_status = 'loginNotCreated'
               AND is_active = FALSE)
         )
         AND mobile IS NULL
         AND firm_name = 'Chirag Accounting'
         AND password_hash LIKE '$2%'
       FOR UPDATE`,
    );

    for (const { id, firmName } of rows) {
      await connection.execute(
        `UPDATE users
         SET role = 'client', account_origin = 'selfRegistered',
             client_status = 'pendingApproval', login_status = 'loginNotCreated',
             is_active = FALSE, must_change_password = FALSE,
             identity_revision = GREATEST(identity_revision, 1) + 1,
             updated_at = CURRENT_TIMESTAMP
         WHERE id = ?`,
        [id],
      );
      await connection.execute(
        `INSERT INTO client_profiles (client_id, legal_name, created_by, updated_by)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE legal_name = IF(legal_name = '', ?, legal_name)`,
        [id, firmName, id, id, firmName],
      );
      await connection.execute(
        `INSERT INTO client_compliance (
           client_id, gst_registration_type, accounting_enabled, gst_enabled,
           services_json, service_periods_json, created_by, updated_by
         ) VALUES (?, 'unregistered', TRUE, FALSE, JSON_ARRAY(), JSON_ARRAY(), ?, ?)
         ON DUPLICATE KEY UPDATE client_id = client_id`,
        [id, id, id],
      );
      await connection.execute(
        `INSERT INTO client_access_policies (
           client_id, modules_json, dashboard_widgets_json, document_hub_access_json,
           created_by, updated_by
         ) VALUES (?, JSON_OBJECT(), JSON_OBJECT(), JSON_OBJECT(), ?, ?)
         ON DUPLICATE KEY UPDATE client_id = client_id`,
        [id, id, id],
      );
      await connection.execute(
        `INSERT INTO client_workspaces (client_id, created_by, updated_by)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE client_id = client_id`,
        [id, id, id],
      );
      await connection.execute(
        `INSERT INTO client_data_change_log (
           client_id, actor_user_id, change_type, payload_json
         ) SELECT ?, ?, 'client.selfRegistrationReconciled', JSON_OBJECT()
           WHERE NOT EXISTS (
             SELECT 1
             FROM client_data_change_log
             WHERE client_id = ? AND change_type = 'client.selfRegistrationReconciled'
           )`,
        [id, id, id],
      );
    }
    await connection.commit();
    if (rows.length > 0) {
      console.log(`Reconciled ${rows.length} legacy self-registration record(s).`);
    }
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}