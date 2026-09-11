import { Request, Response } from 'express';
import { z } from 'zod';

import { CommandService } from '../services/commandService.js';

const executeSchema = z.object({
  input_type: z.enum(['text', 'voice', 'ocr']),
  transcript: z.string().min(1),
  conversation_id: z.string().optional().nullable(),
  session_id: z.string().optional().nullable(),
  idempotency_key: z.string().optional().nullable(),
  client_context: z
    .object({
      screen: z.string().optional().nullable(),
      voucher_id: z.string().optional().nullable(),
      module: z.string().optional().nullable(),
    })
    .optional(),
});

const confirmSchema = z.object({
  command_id: z.string().min(1),
  conversation_id: z.string().min(1),
});

const cancelSchema = z.object({
  command_id: z.string().min(1),
  conversation_id: z.string().min(1),
});

export class CommandController {
  constructor(private readonly service: CommandService) {}

  execute = async (req: Request, res: Response) => {
    const body = executeSchema.parse(req.body);
    const context = req.securityContext;
    if (!context) {
      res.status(401).json({ message: 'Unauthorized' });
      return;
    }

    const response = await this.service.execute(
      {
        inputType: body.input_type,
        transcript: body.transcript,
        conversationId: body.conversation_id,
        sessionId: body.session_id,
        idempotencyKey: body.idempotency_key,
      },
      context,
    );

    res.json(response);
  };

  confirm = async (req: Request, res: Response) => {
    const body = confirmSchema.parse(req.body);
    const context = req.securityContext;
    if (!context) {
      res.status(401).json({ message: 'Unauthorized' });
      return;
    }

    const response = await this.service.confirm(body.command_id, body.conversation_id, context);
    res.json(response);
  };

  cancel = async (req: Request, res: Response) => {
    const body = cancelSchema.parse(req.body);
    const context = req.securityContext;
    if (!context) {
      res.status(401).json({ message: 'Unauthorized' });
      return;
    }

    const response = await this.service.cancel(body.command_id, body.conversation_id, context);
    res.json(response);
  };

  status = async (req: Request, res: Response) => {
    const context = req.securityContext;
    if (!context) {
      res.status(401).json({ message: 'Unauthorized' });
      return;
    }

    const response = await this.service.status(req.params.commandId, context);
    if (response.error_code === 'NOT_FOUND') {
      res.status(404).json(response);
      return;
    }
    res.json(response);
  };
}
