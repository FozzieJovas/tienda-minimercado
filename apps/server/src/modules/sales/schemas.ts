import { z } from "zod";

export const saleItemInputSchema = z.object({
  productId: z.string(),
  cantidad: z.number().positive(),
});

export const saleCreateSchema = z.object({
  usuarioId: z.string().optional(),
  sesionId: z.string().optional(),
  descuento: z.number().nonnegative().default(0),
  medioPago: z.enum(["EFECTIVO", "TARJETA", "TRANSFERENCIA", "MIXTO"]).default("EFECTIVO"),
  montoRecibido: z.number().nonnegative().optional(),
  // Requerido solo cuando medioPago = MIXTO: cuánto del total se pagó en efectivo (el resto, otro medio).
  montoEfectivo: z.number().nonnegative().optional(),
  items: z.array(saleItemInputSchema).min(1),
});

export type SaleCreateInput = z.infer<typeof saleCreateSchema>;
