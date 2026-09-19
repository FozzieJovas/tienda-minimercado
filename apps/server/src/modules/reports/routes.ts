import type { FastifyPluginAsync } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { prisma } from "../../db/client.js";

function startOfToday(): Date {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

export const reportRoutes: FastifyPluginAsync = async (app) => {
  const server = app.withTypeProvider<ZodTypeProvider>();

  server.get("/reports/sales-today", { schema: { tags: ["reports"] } }, async () => {
    const ventas = await prisma.sale.findMany({
      where: { fecha: { gte: startOfToday() }, estado: "COMPLETADA" },
      include: { items: true },
      orderBy: { fecha: "asc" },
    });

    const porMedioPago: Record<string, { cantidadVentas: number; total: number }> = {};
    let totalGeneral = 0;
    for (const venta of ventas) {
      const bucket = porMedioPago[venta.medioPago] ?? { cantidadVentas: 0, total: 0 };
      bucket.cantidadVentas += 1;
      bucket.total = Math.round((bucket.total + venta.total) * 100) / 100;
      porMedioPago[venta.medioPago] = bucket;
      totalGeneral = Math.round((totalGeneral + venta.total) * 100) / 100;
    }

    return {
      fecha: startOfToday().toISOString(),
      cantidadVentas: ventas.length,
      totalGeneral,
      porMedioPago,
      ventas,
    };
  });

  server.get("/reports/low-stock", { schema: { tags: ["reports"] } }, async () => {
    const productos = await prisma.product.findMany({
      where: { activo: true },
      include: { categoria: true },
    });
    return productos.filter((p) => p.stockActual <= p.stockMinimo);
  });
};
