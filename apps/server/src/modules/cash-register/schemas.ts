import { z } from "zod";

export const openSessionSchema = z.object({
  usuarioAperturaId: z.string().optional(),
  fondoInicial: z.number().nonnegative(),
});

export const cashMovementSchema = z.object({
  tipo: z.enum(["INGRESO", "RETIRO"]),
  monto: z.number().positive(),
  motivo: z.string().optional(),
});

export const closeSessionSchema = z.object({
  usuarioCierreId: z.string().optional(),
  efectivoContado: z.number().nonnegative(),
});
