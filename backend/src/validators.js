import { z } from 'zod';

export const checkoutProviderSchema = z.enum(['toss', 'lemon']);

export const createCheckoutSessionSchema = z.object({
  installationId: z.string().uuid(),
  customerEmail: z.string().email().optional().or(z.literal('')).transform((value) => value || undefined),
  source: z.enum(['app', 'web']).optional().default('app'),
  appVersion: z.string().trim().max(32).optional(),
  provider: checkoutProviderSchema.optional()
});

export const sessionLookupSchema = z.object({
  sessionId: z.string().uuid(),
  installationId: z.string().uuid()
});

export const claimCheckoutSessionSchema = z.object({
  installationId: z.string().uuid()
});

export const publicCheckoutSchema = z.object({
  customerEmail: z.string().email().optional().or(z.literal('')).transform((value) => value || undefined),
  provider: checkoutProviderSchema.optional()
});

export const activateLicenseSchema = z.object({
  licenseKey: z.string().trim().min(1),
  installationId: z.string().uuid(),
  instanceName: z.string().trim().min(1).max(120),
  customerEmail: z.string().email().optional().or(z.literal('')).transform((value) => value || undefined)
});

export const validateLicenseSchema = z.object({
  licenseKey: z.string().trim().min(1),
  instanceId: z.string().trim().optional()
});

export const deactivateLicenseSchema = z.object({
  licenseKey: z.string().trim().min(1),
  instanceId: z.string().trim().min(1)
});
