process.env.NODE_ENV = 'test';
process.env.JWT_SECRET ??= 'unit-test-secret-unit-test-secret';
process.env.DB_HOST ??= 'localhost';
process.env.DB_USER ??= 'unit-test';
process.env.DB_PASSWORD ??= 'unit-test';
process.env.DB_NAME ??= 'unit-test';
process.env.PORTAL_CREDENTIAL_ENCRYPTION_KEY =
  '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';