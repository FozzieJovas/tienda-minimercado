import type { FastifyPluginAsync } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../../db/client.js";
import { purchaseCreateSchema } from "./schemas.js";
import { calcularPrecioVenta, resolveMargin } from "../products/pricing.js";

export const purchaseRoutes: FastifyPluginAsync = async (app) => {
  const server = app.withTypeProvider<ZodTypeProvider>();

  server.get("/purchases", { schema: { tags: ["purchases"] } }, async () => {
    return prisma.purchaseInvoice.findMany({
      include: { items: { include: { product: true } }, supplier: true },
      orderBy: { createdAt: "desc" },
    });
  });

  server.get(
    "/purchases/:id",
    { schema: { tags: ["purchases"], params: z.object({ id: z.string() }) } },
    async (request, reply) => {
      const purchase = await prisma.purchaseInvoice.findUnique({
        where: { id: request.params.id },
        include: { items: { include: { product: true } }, supplier: true },
      });
      if (!purchase) return reply.code(404).send({ error: "Compra no encontrada" });
      return purchase;
    }
  );

  server.post(
    "/purchases",
    { schema: { tags: ["purchases"], body: purchaseCreateSchema } },
    async (request, reply) => {
      const { items, supplierId, numeroFactura, fecha, creadoPorId } = request.body;

      const products = await prisma.product.findMany({
        where: { id: { in: items.map((i) => i.productId) } },
        include: { categoria: true },
      });
      const productMap = new Map(products.map((p) => [p.id, p]));

      for (const item of items) {
        if (!productMap.has(item.productId)) {
          return reply.code(400).send({ error: `Producto ${item.productId} no existe` });
        }
      }

      const purchaseItemsData = items.map((item) => {
        const product = productMap.get(item.productId)!;
        const subtotal = Math.round(item.costoUnitario * item.cantidad * 100) / 100;
        return {
          productId: item.productId,
          descripcionCruda: product.nombre,
          cantidad: item.cantidad,
          costoUnitario: item.costoUnitario,
          subtotal,
        };
      });
      const total = purchaseItemsData.reduce((sum, i) => sum + i.subtotal, 0);

      const purchase = await prisma.$transaction(async (tx) => {
        const created = await tx.purchaseInvoice.create({
          data: {
            supplierId,
            numeroFactura,
            fecha: fecha ? new Date(fecha) : new Date(),
            creadoPorId,
            estado: "CONFIRMADA",
            total,
            items: { create: purchaseItemsData },
          },
          include: { items: { include: { product: true } }, supplier: true },
        });

        for (const item of items) {
          const product = productMap.get(item.productId)!;
          const margen = await resolveMargin({
            margenOverride: product.margenOverride,
            categoriaMargenDefault: product.categoria?.margenDefault,
          });

          await tx.product.update({
            where: { id: item.productId },
            data: {
              stockActual: { increment: item.cantidad },
              costoActual: item.costoUnitario,
              precioVenta: calcularPrecioVenta(item.costoUnitario, margen),
            },
          });
          await tx.stockMovement.create({
            data: {
              productId: item.productId,
              tipo: "COMPRA",
              cantidadDelta: item.cantidad,
              referenciaTipo: "purchase",
              referenciaId: created.id,
            },
          });
        }

        return created;
      });

      return reply.code(201).send(purchase);
    }
  );
};
