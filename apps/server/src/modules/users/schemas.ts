import { z } from "zod";

export const userCreateSchema = z.object({
  nombre: z.string().min(1),
  usuario: z.string().min(1),
  password: z.string().min(4),
  rol: z.enum(["ADMIN", "CAJERO", "INVENTARIO"]).default("CAJERO"),
});

export const userUpdateSchema = z.object({
  nombre: z.string().min(1).optional(),
  password: z.string().min(4).optional(),
  rol: z.enum(["ADMIN", "CAJERO", "INVENTARIO"]).optional(),
  activo: z.boolean().optional(),
});
