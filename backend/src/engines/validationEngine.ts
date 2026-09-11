import { z } from 'zod';

const createSalesDraftSchema = z.object({
  customer: z.string().min(2),
  item: z.string().min(2),
  quantity: z.number().positive(),
  rate: z.number().positive(),
  unit: z.string().min(1),
});

export class ValidationEngine {
  validateSalesDraft(payload: Record<string, unknown>): { ok: true } | { ok: false; message: string } {
    const result = createSalesDraftSchema.safeParse(payload);
    if (!result.success) {
      return { ok: false, message: 'Required invoice fields are incomplete.' };
    }
    return { ok: true };
  }
}
