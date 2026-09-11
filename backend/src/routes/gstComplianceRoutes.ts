import { Router } from 'express';
import { z } from 'zod';

import {
  GstComplianceGatewayService,
  GstComplianceOperation,
} from '../services/compliance/gstComplianceGatewayService.js';

const operations: readonly GstComplianceOperation[] = [
  'gstr1-download', 'gstr1-save', 'gstr1-reset', 'gstr1-file', 'gstr1a-download',
  'gstr1a-save', 'gstr1a-reset', 'gstr1a-file', 'gstr1a-status',
  'gstr2-b2b', 'gstr2-b2ba', 'gstr2-cdn', 'gstr2-cdna', 'gstr2-impg',
  'gstr2-impgsez', 'gstr2-isd', 'gstr2-2b', 'gstr2-tdstcs', 'gstr2-ecom',
  'gstr2-ecoma', 'gstr3b-auto-liability', 'gstr3b-interest', 'gstr3b-save',
  'gstr3b-offset', 'gstr3b-summary', 'gstr3b-cash-itc-balance', 'ims',
  'ims-invoice-count', 'ims-file-details', 'ims-save-actions',
  'ims-reset-actions', 'ims-request-status', 'return-status', 'generate-otp',
  'generate-evc-otp', 'establish-session', 'refresh-session', 'file-details',
  'download', 'delete-invoice', 'login-token', 'create-gstin',
  'einvoice-login-session', 'post-purchase-data', 'reconciliation-status',
  'sign-pdf',
];

export function gstComplianceRoutes(service = new GstComplianceGatewayService()) {
  const router = Router();
  for (const operation of operations) {
    router.post(`/gst/compliance/${operation}`, async (req, res, next) => {
      try {
        res.json(await service.execute(operation, req.body ?? {}));
      } catch (error) {
        next(error);
      }
    });
  }

  router.post('/gst/gstr1', async (req, res, next) => {
    try {
      res.json(await service.execute('gstr1-download', { ...req.query, ...req.body }));
    } catch (error) {
      next(error);
    }
  });
  router.post('/gst/gstr3b', async (req, res, next) => {
    try {
      res.json(await service.execute('gstr3b-summary', { ...req.query, ...req.body }));
    } catch (error) {
      next(error);
    }
  });
  router.post('/gst/gstr2b/matching', async (req, res, next) => {
    try {
      res.json(await service.execute('gstr2-2b', { ...req.query, ...req.body }));
    } catch (error) {
      next(error);
    }
  });
  router.post('/gst/returns/status', async (req, res, next) => {
    try {
      res.json(await service.execute('return-status', { ...req.query, ...req.body }));
    } catch (error) {
      next(error);
    }
  });
  router.post('/gst/analytics', async (req, res, next) => {
    try {
      res.json(await service.execute('reconciliation-status', { ...req.query, ...req.body }));
    } catch (error) {
      next(error);
    }
  });

  router.post('/gst/gstr1/bulk-file', async (req, res, next) => {
    try {
      const context = req.securityContext;
      if (!context || !['super_admin', 'admin', 'manager', 'accountant'].includes(context.role)) {
        res.status(403).json({ message: 'Only authorized accounting users can file returns in bulk.' });
        return;
      }

      const input = z.object({
        returns: z.array(z.object({
          clientId: z.string().min(1),
          gstin: z.string().trim().toUpperCase().regex(/^[0-9A-Z]{15}$/),
          returnPeriod: z.string().trim().min(1).max(16),
          payload: z.record(z.string(), z.unknown()).default({}),
        })).min(1).max(25),
      }).parse(req.body);

      const results = await Promise.all(input.returns.map(async (item) => {
        try {
          const response = await service.execute('gstr1-file', {
            ...item.payload,
            gstin: item.gstin,
            ret_period: item.returnPeriod,
          });
          return { clientId: item.clientId, gstin: item.gstin, returnPeriod: item.returnPeriod, status: 'filed', response };
        } catch (error) {
          return {
            clientId: item.clientId,
            gstin: item.gstin,
            returnPeriod: item.returnPeriod,
            status: 'failed',
            error: error instanceof Error ? error.message : 'GSTR-1 filing failed.',
          };
        }
      }));

      res.json({
        message: `Processed ${results.length} GSTR-1 filing request(s).`,
        results,
      });
    } catch (error) {
      next(error);
    }
  });
  return router;
}