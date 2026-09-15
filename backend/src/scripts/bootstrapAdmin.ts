import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import type { ResultSetHeader, RowDataPacket } from 'mysql2';

import pool from '../database.js';
import { hashPassword } from '../services/authService.js';

const name = requiredEnvironmentValue('BOOTSTRAP_ADMIN_NAME');
const email = requiredEnvironmentValue('BOOTSTRAP_ADMIN_EMAIL').toLowerCase();
const mobile = requiredEnvironmentValue('BOOTSTRAP_ADMIN_MOBILE').replace(/\D/g, '');
const firmName = process.env.BOOTSTRAP_ADMIN_FIRM?.trim() || 'Chirag Accounting';
const outputFile = process.env.BOOTSTRAP_OUTPUT_FILE?.trim() || '/tmp/chirag-admin-credentials.txt';

if (!/^\S+@\S+\.\S+$/.test(email)) throw new Error('BOOTSTRAP_ADMIN_EMAIL is invalid.');
if (!/^\d{10}$/.test(mobile)) throw new Error('BOOTSTRAP_ADMIN_MOBILE must contain 10 digits.');

const password = generatePassword();
const [existingUsers] = await pool.execute<RowDataPacket[]>(
  'SELECT id FROM users WHERE email = ? OR mobile = ? LIMIT 1',
  [email, mobile],
);
const created = existingUsers.length === 0;

if (created) {
  await pool.execute<ResultSetHeader>(
    `INSERT INTO users (
      name, email, mobile, firm_name, password_hash, role, is_active, must_change_password
    ) VALUES (?, ?, ?, ?, ?, 'super_admin', 1, 1)`,
    [name, email, mobile, firmName, await hashPassword(password)],
  );
}

if (created) {
  await fs.writeFile(
    outputFile,
    `Email: ${email}\nTemporary password: ${password}\nPassword change required: yes\n`,
    { encoding: 'utf8', mode: 0o600 },
  );
  console.log(`Super-admin created. Credentials were written to ${outputFile}.`);
} else {
  console.log(`User ${email} already exists; no credentials were changed.`);
}
await pool.end();
process.exit(0);

function requiredEnvironmentValue(name: string) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function generatePassword() {
  const groups = [
    'ABCDEFGHJKLMNPQRSTUVWXYZ',
    'abcdefghijkmnopqrstuvwxyz',
    '23456789',
    '@#%!',
  ];
  const all = groups.join('');
  const characters = groups.map((group) => group[crypto.randomInt(group.length)]);
  while (characters.length < 16) characters.push(all[crypto.randomInt(all.length)]);
  return characters.sort(() => crypto.randomInt(3) - 1).join('');
}