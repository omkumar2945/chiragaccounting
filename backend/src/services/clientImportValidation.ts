import { z } from 'zod';

const gstRegistrationTypes = ['unregistered', 'regular', 'composition'] as const;

const clientImportSchema = z.object({
  name: z.string().trim().min(1, 'Name is required.').max(200),
  email: z.string().trim().email('A valid email is required.').max(320).transform((value) => value.toLowerCase()),
  mobile: z.string().trim().transform(normalizeMobile).refine(
    (value) => /^\d{10}$/.test(value),
    'A valid 10-digit mobile number is required.',
  ),
  firmName: z.string().trim().max(200).optional(),
  companyName: z.string().trim().max(200).optional(),
  sourceRecordId: z.string().trim().min(1).max(255).optional(),
  gstRegistrationType: z.enum(gstRegistrationTypes).optional(),
  gstin: z.string().trim().max(15).transform((value) => value.toUpperCase()).optional(),
  pan: z.string().trim().max(20).transform((value) => value.toUpperCase()).optional(),
  state: z.string().trim().max(120).optional(),
  city: z.string().trim().max(120).optional(),
  pincode: z.string().trim().max(12).optional(),
  accountingEnabled: z.boolean().optional(),
  gstEnabled: z.boolean().optional(),
  services: z.array(z.string().trim().min(1).max(100)).max(50).optional(),
}).transform((input) => ({
  ...input,
  firmName: input.firmName || input.companyName || input.name,
  sourceRecordId: input.sourceRecordId || `${input.email}:${input.mobile}`,
}));

export type ImportedClient = z.infer<typeof clientImportSchema>;

export interface ExistingUserIdentity {
  id: number | string;
  email: string;
  mobile: string;
  role: string;
}

export type ImportIdentityDecision =
  | { action: 'create' }
  | { action: 'update'; userId: number }
  | { action: 'conflict'; reason: string };

export function parseImportedClient(entry: unknown) {
  return clientImportSchema.safeParse(entry);
}

export function importValidationMessage(error: z.ZodError) {
  return error.issues
    .map((issue) => `${issue.path.join('.') || 'row'}: ${issue.message}`)
    .join('; ');
}

export function decideImportIdentity(
  input: ImportedClient,
  existing: ExistingUserIdentity[],
): ImportIdentityDecision {
  const matches = existing.filter((user) =>
    normalizeEmail(user.email) === input.email || normalizeMobile(user.mobile) === input.mobile,
  );

  if (matches.length === 0) return { action: 'create' };
  if (matches.length !== 1) {
    return { action: 'conflict', reason: 'Email and mobile resolve to different existing accounts.' };
  }

  const user = matches[0];
  if (user.role.trim().toLowerCase() !== 'client') {
    return { action: 'conflict', reason: 'The matching identity belongs to a non-client account.' };
  }
  if (normalizeEmail(user.email) !== input.email || normalizeMobile(user.mobile) !== input.mobile) {
    return { action: 'conflict', reason: 'Email and mobile do not both match the same existing client.' };
  }
  return { action: 'update', userId: Number(user.id) };
}

function normalizeEmail(value: string) {
  return value.trim().toLowerCase();
}

export function normalizeMobile(value: string) {
  const digits = value.replace(/\D/g, '');
  return digits.length === 12 && digits.startsWith('91') ? digits.slice(2) : digits;
}