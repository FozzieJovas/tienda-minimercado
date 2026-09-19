import type { FastifyPluginAsync } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../../db/client.js";
import { openSessionSchema, cashMovementSchema, closeSessionSchema } from "./schemas.js";

function efectivoDeVenta(venta: { medioPago: string; total: number; montoEfectivo: number | null }): number {
  if (venta.medioPago === "EFECTIVO") return venta.total;
  if (venta.medioPago === "MIXTO") return venta.montoEfectivo ?? 0;
  return 0;
}

export const cashRegisterRoutes: FastifyPluginAsync = async (app) => {
  const server = app.withTypeProvider<ZodTypeProvider>();

  server.get("/cash-sessions/current", { schema: { tags: ["cash-register"] } }, async (_request, reply) => {
    const session = await prisma.cashRegisterSession.findFirst({
      where: { estado: "ABIERTA" },
      include: { movimientos: true },
    });
    if (!session) return reply.code(404).send({ error: "No hay turno de caja abierto" });
    return session;
  });

  server.get(
    "/cash-sessions/:id",
    { schema: { tags: ["cash-register"], params: z.object({ id: z.string() }) } },
    async (request, reply) => {
      const session = await prisma.cashRegisterSession.findUnique({
        where: { id: request.params.id },
        include: {
          movimientos: true,
          ventas: { where: { estado: "COMPLETADA" }, include: { items: true } },
        },
      });
      if (!session) return reply.code(404).send({ error: "Turno no encontrado" });
      return session;
    }
  );

  server.post(
    "/cash-sessions",
    { schema: { tags: ["cash-register"], body: openSessionSchema } },
    async (request, reply) => {
      const existing = await prisma.cashRegisterSession.findFirst({ where: { estado: "ABIERTA" } });
      if (existing) return reply.code(400).send({ error: "Ya hay un turno de caja abierto" });

      const session = await prisma.cashRegisterSession.create({
        data: {
          usuarioAperturaId: request.body.usuarioAperturaId,
          fondoInicial: request.body.fondoInicial,
        },
      });
      return reply.code(201).send(session);
    }
  );

  server.post(
    "/cash-sessions/:id/movements",
    {
      schema: {
        tags: ["cash-register"],
        params: z.object({ id: z.string() }),
        body: cashMovementSchema,
      },
    },
    async (request, reply) => {
      const session = await prisma.cashRegisterSession.findUnique({ where: { id: request.params.id } });
      if (!session) return reply.code(404).send({ error: "Turno no encontrado" });
      if (session.estado !== "ABIERTA") return reply.code(400).send({ error: "El turno ya está cerrado" });

      const movimiento = await prisma.cashMovement.create({
        data: { sesionId: session.id, ...request.body },
      });
      return reply.code(201).send(movimiento);
    }
  );

  server.post(
    "/cash-sessions/:id/cerrar",
    {
      schema: {
        tags: ["cash-register"],
        params: z.object({ id: z.string() }),
        body: closeSessionSchema,
      },
    },
    async (request, reply) => {
      const session = await prisma.cashRegisterSession.findUnique({
        where: { id: request.params.id },
        include: {
          movimientos: true,
          ventas: { where: { estado: "COMPLETADA" } },
        },
      });
      if (!session) return reply.code(404).send({ error: "Turno no encontrado" });
      if (session.estado !== "ABIERTA") return reply.code(400).send({ error: "El turno ya está cerrado" });

      const ingresos = session.movimientos
        .filter((m) => m.tipo === "INGRESO")
        .reduce((sum, m) => sum + m.monto, 0);
      const retiros = session.movimientos
        .filter((m) => m.tipo === "RETIRO")
        .reduce((sum, m) => sum + m.monto, 0);
      const ventasEfectivo = session.ventas.reduce((sum, v) => sum + efectivoDeVenta(v), 0);

      const efectivoEsperado =
        Math.round((session.fondoInicial + ventasEfectivo + ingresos - retiros) * 100) / 100;
      const diferencia = Math.round((request.body.efectivoContado - efectivoEsperado) * 100) / 100;

      const closed = await prisma.cashRegisterSession.update({
        where: { id: session.id },
        data: {
          estado: "CERRADA",
          cerradoEn: new Date(),
          usuarioCierreId: request.body.usuarioCierreId,
          efectivoContado: request.body.efectivoContado,
          efectivoEsperado,
          diferencia,
        },
      });
      return closed;
    }
  );
};
