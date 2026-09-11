import { Router } from 'express';

import { GstZenService } from '../services/compliance/gstZenService.js';
import {
  ClientGstPortalConnectionService,
  ClientGstPortalConnectionType,
} from '../services/compliance/clientGstPortalConnectionService.js';

export function gstZenRoutes(service = new GstZenService()) {
  const router = Router();
  const portalConnections = new ClientGstPortalConnectionService();

  const clientConnection = (connectionType: ClientGstPortalConnectionType) => {
    router.get(`/gstzen/client-connections/${connectionType}`, async (req, res, next) => {
      try {
        if (req.securityContext?.role !== 'client') {
          res.status(403).json({ message: 'Client portal access required.' });
          return;
        }
        res.json(await portalConnections.get(req.securityContext, connectionType));
      } catch (error) {
        next(error);
      }
    });

    router.put(`/gstzen/client-connections/${connectionType}`, async (req, res, next) => {
      try {
        if (req.securityContext?.role !== 'client') {
          res.status(403).json({ message: 'Client portal access required.' });
          return;
        }
        res.json(await portalConnections.save(req.securityContext, connectionType, req.body));
      } catch (error) {
        next(error);
      }
    });
  };

  clientConnection('einvoicing');
  clientConnection('eway_bill');

  router.get('/gstzen/status', (_req, res) => {
    res.json(service.status);
  });

  router.get('/gstzen/version', async (_req, res, next) => {
    try {
      res.json(await service.version());
    } catch (error) {
      next(error);
    }
  });

  router.post('/gstzen/gstin/validate', async (req, res, next) => {
    try {
      res.json(await service.validateGstin(req.body?.gstin ?? ''));
    } catch (error) {
      next(error);
    }
  });

  router.post('/gstzen/einvoice/generate', async (req, res, next) => {
    try {
      res.json(await service.generateEInvoice(req.body));
    } catch (error) {
      next(error);
    }
  });

  router.post('/gstzen/einvoice/cancel', async (req, res, next) => {
    try {
      res.json(await service.cancelEInvoice(req.body));
    } catch (error) {
      next(error);
    }
  });

  router.post('/gstzen/einvoice/get', async (req, res, next) => {
    try {
      res.json(await service.getEInvoice(req.body));
    } catch (error) {
      next(error);
    }
  });

  router.post('/gstzen/eway-bill/generate', async (req, res, next) => {
    try {
      res.json(await service.generateEWayBill(req.body));
    } catch (error) {
      next(error);
    }
  });

  router.post('/gstzen/eway-bill/cancel', async (req, res, next) => {
    try {
      res.json(await service.cancelEWayBill(req.body));
    } catch (error) {
      next(error);
    }
  });

  const gstin = (value: string | undefined) => value?.trim() ?? '';
  const standalonePost = (
    path: string,
    operation: (
      payload: Record<string, unknown>,
      gstin: string,
    ) => Promise<unknown>,
  ) => {
    router.post(path, async (req, res, next) => {
      try {
        res.json(await operation(req.body, gstin(req.get('X-GSTIN'))));
      } catch (error) {
        next(error);
      }
    });
  };

  standalonePost('/gstzen/eway-bill/create', (payload, value) =>
    service.createEWayBill(payload, value),
  );
  standalonePost('/gstzen/eway-bill/standalone/cancel', (payload, value) =>
    service.cancelStandaloneEWayBill(payload, value),
  );
  standalonePost('/gstzen/eway-bill/update-part-b', (payload, value) =>
    service.updateEWayBillPartB(payload, value),
  );
  standalonePost('/gstzen/eway-bill/update-transporter', (payload, value) =>
    service.updateEWayBillTransporter(payload, value),
  );
  standalonePost('/gstzen/eway-bill/get', (payload, value) =>
    service.getEWayBill(payload, value),
  );
  standalonePost('/gstzen/eway-bill/consolidated/generate', (payload, value) =>
    service.generateConsolidatedEWayBill(payload, value),
  );
  standalonePost('/gstzen/eway-bill/consolidated/get', (payload, value) =>
    service.getConsolidatedEWayBill(payload, value),
  );
  standalonePost('/gstzen/eway-bill/extend', (payload, value) =>
    service.extendEWayBill(payload, value),
  );
  standalonePost('/gstzen/eway-bill/multi-vehicle/initiate', (payload, value) =>
    service.initiateMultiVehicleMovement(payload, value),
  );
  standalonePost('/gstzen/eway-bill/multi-vehicle/add', (payload, value) =>
    service.addMultiVehicles(payload, value),
  );
  standalonePost('/gstzen/eway-bill/multi-vehicle/change', (payload, value) =>
    service.changeMultiVehicles(payload, value),
  );
  standalonePost('/gstzen/eway-bill/close', (payload, value) =>
    service.closeEWayBill(payload, value),
  );

  router.post('/gstzen/eway-bill/transporter-view', async (req, res, next) => {
    try {
      res.json(await service.getTransporterView(req.body));
    } catch (error) {
      next(error);
    }
  });

  router.post('/gstzen/eway-bill/transporter-state-view', async (req, res, next) => {
    try {
      res.json(await service.getTransporterStateView(req.body));
    } catch (error) {
      next(error);
    }
  });

  router.post('/gstzen/eway-bill/transporter-gstin-view', async (req, res, next) => {
    try {
      res.json(await service.getTransporterGstinView(req.body));
    } catch (error) {
      next(error);
    }
  });

  return router;
}