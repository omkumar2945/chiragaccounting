import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import mysql from 'mysql2';

dotenv.config({
  path: fileURLToPath(new URL('.env', import.meta.url)),
  quiet: true,
});

const requiredVariables = ['DB_HOST', 'DB_USER', 'DB_PASSWORD'];
const missingVariables = requiredVariables.filter((name) => !process.env[name]);

if (missingVariables.length > 0) {
  console.error(`Missing required database configuration: ${missingVariables.join(', ')}`);
  process.exitCode = 1;
} else {
  const connection = mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT ?? 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  connection.connect((error) => {
    if (error) {
      console.error('Connection failed:', error.message);
      process.exitCode = 1;
      return;
    }

    console.log('Connection successful.');
    connection.end();
  });
}
