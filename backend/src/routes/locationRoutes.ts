import { Router } from 'express';

import { LocationService } from '../services/location/locationService.js';

export function locationRoutes(service = new LocationService()) {
  const router = Router();

  router.get('/locations/pincode/:pincode', async (req, res, next) => {
    try {
      const pincode = req.params.pincode.trim();
      if (!/^\d{6}$/.test(pincode)) {
        res.status(400).json({
          locations: [],
          message: 'Indian pincode must contain 6 digits.',
        });
        return;
      }
      const locations = await service.lookupIndianPincode(pincode);
      res.json({ locations });
    } catch (error) {
      next(error);
    }
  });

  return router;
}