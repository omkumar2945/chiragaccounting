import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import mysql from 'mysql2/promise';

dotenv.config();

const setupDatabase = async () => {
  let connection;

  try {
    connection = await mysql.createConnection({
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT) || 3306,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
    });

    await connection.query('CREATE DATABASE IF NOT EXISTS myapp');
    await connection.query('USE myapp');

    await connection.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        role ENUM('super_admin', 'admin', 'user') DEFAULT 'user',
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);

    const [passwordColumns] = await connection.query(
      `SELECT column_name AS columnName
       FROM information_schema.columns
       WHERE table_schema = 'myapp'
         AND table_name = 'users'
         AND column_name IN ('password', 'password_hash')`,
    );
    const columnNames = new Set(passwordColumns.map((column) => column.columnName));
    if (!columnNames.has('password_hash')) {
      await connection.query('ALTER TABLE users ADD COLUMN password_hash VARCHAR(255) NULL');
      if (columnNames.has('password')) {
        await connection.query(
          'UPDATE users SET password_hash = password WHERE password_hash IS NULL',
        );
      }
    }

    const hashedPassword = await bcrypt.hash('Admin@123', 10);
    await connection.query(
      `INSERT INTO users (name, email, password_hash, role)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         name = VALUES(name),
         password_hash = VALUES(password_hash),
         role = VALUES(role)`,
      ['Super Admin', 'superadmin@chirag.com', hashedPassword, 'super_admin'],
    );

    console.log('Database setup complete!');
    console.log('Email: superadmin@chirag.com');
    console.log('Password: Admin@123');
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    if (connection) {
      await connection.end();
    }
    process.exit(0);
  }
};

setupDatabase();
