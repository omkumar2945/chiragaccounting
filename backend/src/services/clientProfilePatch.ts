import { z } from 'zod';

export const profileFieldNames = [
  'legalName', 'gstin', 'pan', 'aadhaar', 'address', 'city', 'state',
  'pincode', 'country', 'registeredLocation', 'logoFileName', 'logoDataBase64',
  'invoiceFormat', 'documentMetadata',
] as const;

export type ProfileField = (typeof profileFieldNames)[number];

export const clientProfilePatchSchema = z.object({
  name: z.string().trim().min(1).max(200).optional(),
  firmName: z.string().trim().min(1).max(200).optional(),
  legalName: z.string().trim().max(200).optional(),
  gstin: z.string().trim().toUpperCase().max(15).optional(),
  pan: z.string().trim().toUpperCase().max(20).optional(),
  aadhaar: z.string().trim().max(20).optional(),
  address: z.string().trim().max(500).optional(),
  city: z.string().trim().max(120).optional(),
  state: z.string().trim().max(120).optional(),
  pincode: z.string().trim().max(12).optional(),
  country: z.string().trim().max(80).optional(),
  registeredLocation: z.record(z.unknown()).nullable().optional(),
  logoFileName: z.string().trim().max(255).optional(),
  logoDataBase64: z.string().max(500_000).optional(),
  invoiceFormat: z.string().trim().max(100).optional(),
  documentMetadata: z.record(z.unknown()).nullable().optional(),
  ifMatchVersion: z.coerce.number().int().positive().optional(),
  clearFields: z.array(z.enum(profileFieldNames)).max(profileFieldNames.length).default([]),
}).superRefine((input, context) => {
  const supplied = input.name !== undefined || input.firmName !== undefined ||
    profileFieldNames.some((field) => input[field] !== undefined) || input.clearFields.length > 0;
  if (!supplied) context.addIssue({ code: z.ZodIssueCode.custom, message: 'At least one profile field is required.' });
  for (const field of profileFieldNames) {
    const value = input[field];
    if (input.clearFields.includes(field) && value !== undefined) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: [field], message: 'A field cannot be supplied and cleared in the same request.' });
    }
    if (typeof value === 'string' && value.length === 0 && !input.clearFields.includes(field)) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: [field], message: 'Use clearFields to clear an existing value.' });
    }
    if (value === null && !input.clearFields.includes(field)) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: [field], message: 'Use clearFields to clear an existing value.' });
    }
  }
});

export type ClientProfilePatch = z.infer<typeof clientProfilePatchSchema>;