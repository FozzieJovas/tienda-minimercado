import { z } from "zod";

export const productCreateSchema = z.object({
  sku: z.string().optional(),
  barcode: z.string().optional(),
  nombre: z.string().min(1),
  categoriaId: z.string().optional(),
  unidadMedida: z.string().default("unidad"),
  costoActual: z.number().nonnegative().default(0),
  margenOverride: z.number().min(-1).optional(),
  stockActual: z.number().default(0),
  stockMinimo: z.number().nonnegative().default(0),
  favorito: z.boolean().default(false),
});

export const productUpdateSchema = productCreateSchema.partial().extend({
  // A diferencia de create, en update `null` es un valor válido para estos
  // campos: significa "quitarlo" (dejar el producto sin código de barras,
  // sin categoría, o sin margen propio -- volviendo al de categoría/global).
  barcode: z.string().nullable().optional(),
  categoriaId: z.string().nullable().optional(),
  margenOverride: z.number().min(-1).nullable().optional(),
});

export const productParamsSchema = z.object({
  id: z.string(),
});

export type ProductCreateInput = z.infer<typeof productCreateSchema>;
export type ProductUpdateInput = z.infer<typeof productUpdateSchema>;
