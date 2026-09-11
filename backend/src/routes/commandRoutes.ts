import { Router } from 'express';

import { CommandController } from '../controllers/commandController.js';

export function commandRoutes(controller: CommandController) {
  const router = Router();

  router.post('/command', controller.execute);
  router.post('/command/confirm', controller.confirm);
  router.post('/command/cancel', controller.cancel);
  router.get('/command/status/:commandId', controller.status);

  return router;
}
