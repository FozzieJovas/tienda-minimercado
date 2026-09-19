import type { FastifyPluginAsync } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../../db/client.js";
import { saleCreateSchema } from "./schemas.js";

export const saleRoutes: FastifyPluginAsync = async (app) => {
  const server = app.withTypeProvider<ZodTypeProvider>();

  server.get(
    "/sales",
    { schema: { tags: ["sales"], querystring: z.object({ desde: z.string().optional(), hasta: z.string().optional() }) } },
    async (request) => {
      const { desde, hasta } = request.query;
      return prisma.sale.findMany({
        where: {
          fecha: {
            gte: desde ? new Date(desde) : undefined,
            lte: hasta ? new Date(hasta) : undefined,
          },
        },
        include: { items: { include: { product: true } } },
        orderBy: { fecha: "desc" },
      });
    }
  );

  server.get(
    "/sales/:id",
    { schema: { tags: ["sales"], params: z.object({ id: z.string() }) } },
    async (request, reply) => {
      const sale = await prisma.sale.findUnique({
        where: { id: request.params.id },
        include: { items: { include: { product: true } } },
      });
      if (!sale) return reply.code(404).send({ error: "Venta no encontrada" });
      return sale;
    }
  );

  server.post(
    "/sales",
    { schema: { tags: ["sales"], body: saleCreateSchema } },
    async (request, reply) => {
      const { items, descuento, medioPago, montoRecibido, montoEfectivo, usuarioId, sesionId } = request.body;

      const products = await prisma.product.findMany({
        where: { id: { in: items.map((i) => i.productId) } },
      });
      const productMap = new Map(products.map((p) => [p.id, p]));

      for (const item of items) {
        if (!productMap.has(item.productId)) {
          return reply.code(400).send({ error: `Producto ${item.productId} no existe` });
        }
      }

      const saleItemsData = items.map((item) => {
        const product = productMap.get(item.productId)!;
        const subtotal = Math.round(product.precioVenta * item.cantidad * 100) / 100;
        return { ...item, precioUnitario: product.precioVenta, subtotal };
      });

      const subtotal = saleItemsData.reduce((sum, i) => sum + i.subtotal, 0);
      const total = Math.round((subtotal - descuento) * 100) / 100;

      if (medioPago === "EFECTIVO" && montoRecibido !== undefined && montoRecibido < total) {
        return reply.code(400).send({ error: "El monto recibido es menor al total" });
      }
      if (medioPago === "MIXTO" && (montoEfectivo === undefined || montoEfectivo > total)) {
        return reply.code(400).send({ error: "Falta indicar el monto en efectivo del pago mixto" });
      }
      const cambio =
        medioPago === "EFECTIVO" && montoRecibido !== undefined
          ? Math.round((montoRecibido - total) * 100) / 100
          : null;
      const montoEfectivoFinal =
        medioPago === "EFECTIVO" ? total : medioPago === "MIXTO" ? montoEfectivo : null;

      const sale = await prisma.$transaction(async (tx) => {
        const ultimaVenta = await tx.sale.findFirst({ orderBy: { numeroTicket: "desc" } });
        const numeroTicket = (ultimaVenta?.numeroTicket ?? 0) + 1;

        const created = await tx.sale.create({
          data: {
            usuarioId,
            sesionId,
            subtotal,
            descuento,
            total,
            medioPago,
            montoRecibido,
            cambio: cambio ?? undefined,
            montoEfectivo: montoEfectivoFinal ?? undefined,
            numeroTicket,
            items: { create: saleItemsData },
          },
          include: { items: { include: { product: true } } },
        });

        for (const item of saleItemsData) {
          await tx.product.update({
            where: { id: item.productId },
            data: { stockActual: { decrement: item.cantidad } },
          });
          await tx.stockMovement.create({
            data: {
              productId: item.productId,
              tipo: "VENTA",
              cantidadDelta: -item.cantidad,
              referenciaTipo: "sale",
              referenciaId: created.id,
            },
          });
        }

        return created;
      });

      return reply.code(201).send(sale);
    }
  );

  server.post(
    "/sales/:id/anular",
    { schema: { tags: ["sales"], params: z.object({ id: z.string() }) } },
    async (request, reply) => {
      const sale = await prisma.sale.findUnique({ where: { id: request.params.id }, include: { items: true } });
      if (!sale) return reply.code(404).send({ error: "Venta no encontrada" });
      if (sale.estado === "ANULADA") return reply.code(400).send({ error: "La venta ya está anulada" });

      const updated = await prisma.$transaction(async (tx) => {
        for (const item of sale.items) {
          await tx.product.update({
            where: { id: item.productId },
            data: { stockActual: { increment: item.cantidad } },
          });
          await tx.stockMovement.create({
            data: {
              productId: item.productId,
              tipo: "AJUSTE",
              cantidadDelta: item.cantidad,
              referenciaTipo: "sale-anulada",
              referenciaId: sale.id,
            },
          });
        }
        return tx.sale.update({ where: { id: sale.id }, data: { estado: "ANULADA" } });
      });

      return updated;
    }
  );
};
