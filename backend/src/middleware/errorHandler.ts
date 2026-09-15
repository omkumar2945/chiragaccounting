import { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';

export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  if (err instanceof ZodError) {
    res.status(400).json({
      status: 'failed',
      message: 'Invalid request data.',
      error_code: 'INVALID_REQUEST',
      details: process.env.NODE_ENV === 'development' ? err.flatten() : undefined,
    });
    return;
  }

  const message = err instanceof Error ? err.message : 'Unhandled error';
  if (message === 'CLIENT_NOT_FOUND') {
    res.status(404).json({ status: 'failed', message: 'Client not found.', error_code: message });
    return;
  }
  if (message === 'ASSIGNMENT_USER_INVALID') {
    res.status(422).json({
      status: 'failed',
      message: 'Assigned accountant or CA/auditor must be active and have an eligible role.',
      error_code: message,
    });
    return;
  }
  if (message === 'CLIENT_DATA_CONFLICT') {
    res.status(409).json({
      status: 'failed',
      message: 'This client record changed on another device. Refresh and try again.',
      error_code: message,
    });
    return;
  }
  if (message === 'CLIENT_IDENTITY_CONFLICT') {
    res.status(409).json({
      status: 'failed',
      message: 'The email or mobile number is already assigned to another account.',
      error_code: message,
    });
    return;
  }
  if (message === 'CLIENT_ALREADY_ONBOARDED') {
    res.status(409).json({ status: 'failed', message: 'This client is already onboarded.', error_code: message });
    return;
  }
  if (message === 'CLIENT_CREDENTIAL_RESET_UNAVAILABLE') {
    res.status(422).json({ status: 'failed', message: 'Onboard and activate the client before resetting credentials.', error_code: message });
    return;
  }
  if (message === 'CLIENT_DATA_INVALID_VERSION') {
    res.status(500).json({ status: 'failed', message: 'Client data has an invalid revision.', error_code: message });
    return;
  }

  res.status(500).json({
    status: 'failed',
    message: 'Internal processing error.',
    error_code: 'INTERNAL_ERROR',
    details: process.env.NODE_ENV === 'development' ? message : undefined,
  });
}
