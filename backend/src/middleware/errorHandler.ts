import { NextFunction, Request, Response } from 'express';

export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  const message = err instanceof Error ? err.message : 'Unhandled error';
  res.status(500).json({
    status: 'failed',
    message: 'Internal processing error.',
    error_code: 'INTERNAL_ERROR',
    details: process.env.NODE_ENV === 'development' ? message : undefined,
  });
}
