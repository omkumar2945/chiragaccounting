import crypto from 'node:crypto';

import nodemailer from 'nodemailer';

import { env } from '../config/env.js';
import type { AuthUserRecord } from './authService.js';

export class EmailDeliveryConfigurationError extends Error {}

export interface EmailOtpRepository {
  replaceOtp(input: {
    userId: string;
    purpose: string;
    codeHash: string;
    expiresAt: Date;
  }): Promise<void>;
  consumeOtp(input: {
    userId: string;
    purpose: string;
    codeHash: string;
  }): Promise<boolean>;
}

export class EmailOtpService {
  constructor(private readonly repository: EmailOtpRepository) {}

  async send(user: AuthUserRecord, purpose: EmailOtpPurpose) {
    const code = createOtpCode();
    await this.repository.replaceOtp({
      userId: user.id,
      purpose,
      codeHash: hashOtp(code),
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
    });
    await deliverEmailOtp(user.email, code, purpose);
  }

  verify(userId: string, purpose: EmailOtpPurpose, code: string) {
    return this.repository.consumeOtp({ userId, purpose, codeHash: hashOtp(code) });
  }
}

export type EmailOtpPurpose = 'login' | 'password_reset';

export async function deliverEmailOtp(
  email: string,
  code: string,
  purpose: EmailOtpPurpose,
) {
  if (!env.SMTP_HOST || !env.SMTP_USER || !env.SMTP_PASSWORD || !env.SMTP_FROM) {
    throw new EmailDeliveryConfigurationError('Email OTP is not configured. Set SMTP_HOST, SMTP_USER, SMTP_PASSWORD, and SMTP_FROM.');
  }
  const transporter = nodemailer.createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: env.SMTP_SECURE,
    auth: { user: env.SMTP_USER, pass: env.SMTP_PASSWORD },
  });
  await transporter.sendMail({
    from: env.SMTP_FROM,
    to: email,
    subject: purpose === 'password_reset' ? 'Reset your Chirag Accounting password' : 'Your Chirag Accounting verification code',
    text: `Your Chirag Accounting verification code is ${code}. It expires in 10 minutes. Do not share this code.`,
  });
}

function createOtpCode() {
  return crypto.randomInt(100000, 1000000).toString();
}

function hashOtp(code: string) {
  return crypto.createHash('sha256').update(code).digest('hex');
}