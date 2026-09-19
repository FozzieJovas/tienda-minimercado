import { z } from "zod";

export const purchaseItemInputSchema = z.object({
  productId: z.string(),
  cantidad: z.number().positive(),
  costoUnitario: z.number().nonnegative(),
});

export const purchaseCreateSchema = z.object({
  supplierId: z.string().optional(),
  numeroFactura: z.string().optional(),
  fecha: z.string().optional(),
  creadoPorId: z.string().optional(),
  items: z.array(purchaseItemInputSchema).min(1),
});

export type PurchaseCreateInput = z.infer<typeof purchaseCreateSchema>;
