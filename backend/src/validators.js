import { z } from 'zod';

export const assetDownloadRequestSchema = z.object({
  assetId: z.string().trim().min(1).max(120)
});
