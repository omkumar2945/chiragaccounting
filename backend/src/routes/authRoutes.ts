import { Router } from 'express';
import { z } from 'zod';
import { getAuth } from 'firebase-admin/auth';
import { cert, getApps, initializeApp } from 'firebase-admin/app';

import { env, firebaseServiceAccount } from '../config/env.js';
import { SqlAuthRepository } from '../repositories/authRepository.js';
import { AuthenticationError, AuthService } from '../services/authService.js';
import { EmailDeliveryConfigurationError, EmailOtpService } from '../services/emailOtpService.js';

const loginSchema = z.object({
  identifier: z.string().trim().min(1).optional(),
  emailOrMobile: z.string().trim().min(1).optional(),
  email: z.string().trim().min(1).optional(),
  mobile: z.string().trim().min(1).optional(),
  password: z.string().min(1),
  userType: z.enum(['staff', 'client', 'business']).default('staff'),
}).refine(
  (body) => body.identifier || body.emailOrMobile || body.email || body.mobile,
  { message: 'Email or mobile is required.' },
);

const refreshSchema = z.object({ refreshToken: z.string().min(1) });
const emailOtpPurposeSchema = z.enum(['login', 'passwordReset', 'password_reset']).default('login');
const emailOtpFields = z.object({
  identifier: z.string().trim().email().optional(),
  emailOrMobile: z.string().trim().email().optional(),
  email: z.string().trim().email().optional(),
  userType: z.enum(['staff', 'client', 'business']).default('staff'),
  purpose: emailOtpPurposeSchema,
});
const emailOtpRequestSchema = emailOtpFields.refine(
  (body) => body.identifier || body.emailOrMobile || body.email,
  { message: 'A registered email is required.' },
);
const emailOtpVerifySchema = emailOtpFields.extend({ otp: z.string().regex(/^\d{6}$/) }).refine(
  (body) => body.identifier || body.emailOrMobile || body.email,
  { message: 'A registered email is required.' },
);
const resetPasswordSchema = emailOtpFields.extend({
  otp: z.string().regex(/^\d{6}$/),
  newPassword: z.string().min(8).max(200),
}).refine(
  (body) => body.identifier || body.emailOrMobile || body.email,
  { message: 'A registered email is required.' },
);
const firebasePhoneLoginSchema = z.object({
  idToken: z.string().min(1),
  userType: z.enum(['staff', 'client', 'business']).default('staff'),
});

function firebaseAuth() {
  if (getApps().length === 0) {
    if (firebaseServiceAccount) {
      initializeApp({
        credential: cert(firebaseServiceAccount),
      });
    } else {
      initializeApp();
    }
  }
  return getAuth();
}

export function authRoutes(
  repository = new SqlAuthRepository(),
  service = new AuthService(repository),
  emailOtp = new EmailOtpService(repository),
) {
  const router = Router();

  router.post('/auth/send-otp', async (req, res, next) => {
    try {
      const body = emailOtpRequestSchema.parse(req.body);
      const user = await service.requestableUser(emailFrom(body), body.userType);
      if (!user) throw new AuthenticationError('No authorized active account found for this email.');
      await emailOtp.send(user, otpPurpose(body.purpose));
      res.status(202).json({ message: 'Verification code sent to the registered email.' });
    } catch (error) {
      if (error instanceof AuthenticationError) {
        res.status(401).json({ message: error.message });
        return;
      }
      if (error instanceof EmailDeliveryConfigurationError) {
        res.status(503).json({ message: 'Email verification is temporarily unavailable.' });
        return;
      }
      next(error);
    }
  });

  router.post('/auth/verify-otp', async (req, res, next) => {
    try {
      const body = emailOtpVerifySchema.parse(req.body);
      const user = await service.requestableUser(emailFrom(body), body.userType);
      if (!user || !(await emailOtp.verify(user.id, otpPurpose(body.purpose), body.otp))) {
        throw new AuthenticationError('Invalid or expired verification code.');
      }
      if (otpPurpose(body.purpose) === 'password_reset') {
        res.json({ verified: true });
        return;
      }
      res.json(await service.loginWithVerifiedEmail({ identifier: user.email, userType: body.userType }));
    } catch (error) {
      if (error instanceof AuthenticationError) {
        res.status(401).json({ message: error.message });
        return;
      }
      next(error);
    }
  });

  router.post('/auth/forgot-password', async (req, res, next) => {
    try {
      const body = emailOtpRequestSchema.parse({ ...req.body, purpose: 'password_reset' });
      const user = await service.requestableUser(emailFrom(body), 'staff');
      if (!user) throw new AuthenticationError('No active account found for this email.');
      await emailOtp.send(user, 'password_reset');
      res.status(202).json({ message: 'Password reset code sent to the registered email.' });
    } catch (error) {
      if (error instanceof AuthenticationError) {
        res.status(401).json({ message: error.message });
        return;
      }
      if (error instanceof EmailDeliveryConfigurationError) {
        res.status(503).json({ message: 'Password reset is temporarily unavailable.' });
        return;
      }
      next(error);
    }
  });

  router.post('/auth/reset-password', async (req, res, next) => {
    try {
      const body = resetPasswordSchema.parse({ ...req.body, purpose: 'password_reset' });
      const user = await service.requestableUser(emailFrom(body), 'staff');
      if (!user || !(await emailOtp.verify(user.id, 'password_reset', body.otp))) {
        throw new AuthenticationError('Invalid or expired verification code.');
      }
      await service.resetPassword(user.email, body.newPassword);
      res.status(204).send();
    } catch (error) {
      if (error instanceof AuthenticationError) {
        res.status(401).json({ message: error.message });
        return;
      }
      next(error);
    }
  });

  router.post('/auth/login', async (req, res, next) => {
    try {
      const body = loginSchema.parse(req.body);
      const result = await service.login({
        identifier: body.identifier ?? body.emailOrMobile ?? body.email ?? body.mobile ?? '',
        password: body.password,
        userType: body.userType,
      });
      res.json(result);
    } catch (error) {
      if (error instanceof AuthenticationError) {
        res.status(401).json({ message: error.message });
        return;
      }
      next(error);
    }
  });

  router.post('/auth/firebase-phone', async (req, res, next) => {
    try {
      const body = firebasePhoneLoginSchema.parse(req.body);
      const decodedToken = await firebaseAuth().verifyIdToken(body.idToken);
      if (!decodedToken.phone_number) {
        throw new AuthenticationError('Firebase token does not contain a verified phone number.');
      }
      const result = await service.loginWithVerifiedMobile({
        mobile: decodedToken.phone_number,
        userType: body.userType,
      });
      res.json(result);
    } catch (error) {
      if (error instanceof AuthenticationError) {
        res.status(401).json({ message: error.message });
        return;
      }
      next(error);
    }
  });

  router.post('/auth/refresh-token', async (req, res, next) => {
    try {
      const body = refreshSchema.parse(req.body);
      const result = await service.refresh(body.refreshToken);
      res.json(result.token);
    } catch (error) {
      if (error instanceof AuthenticationError) {
        res.status(401).json({ message: error.message });
        return;
      }
      next(error);
    }
  });

  router.post('/auth/logout', async (req, res, next) => {
    try {
      const body = refreshSchema.safeParse(req.body);
      if (body.success) await service.revoke(body.data.refreshToken);
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  });

  return router;
}

function emailFrom(body: { identifier?: string; emailOrMobile?: string; email?: string }) {
  return body.identifier ?? body.emailOrMobile ?? body.email ?? '';
}

function otpPurpose(value: 'login' | 'passwordReset' | 'password_reset') {
  return value === 'login' ? 'login' : 'password_reset';
}