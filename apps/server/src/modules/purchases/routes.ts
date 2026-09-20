import type { FastifyPluginAsync } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { randomUUID } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { z } from "zod";
import { prisma } from "../../db/client.js";
import { purchaseCreateSchema } from "./schemas.js";
import { calcularPrecioVenta, resolveMargin } from "../products/pricing.js";
import { PURCHASE_UPLOADS_DIR } from "../../config/paths.js";
import { extractInvoiceFromImages } from "../../ai/geminiClient.js";
import { matchProduct } from "./matching.js";

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

  server.post("/purchases/scan", { schema: { tags: ["purchases"] } }, async (request, reply) => {
    const parts = request.files();
    const scanId = randomUUID();
    const scanDir = path.join(PURCHASE_UPLOADS_DIR, `scan-${scanId}`);
    await fs.mkdir(scanDir, { recursive: true });

    const images: { base64: string; mimeType: string }[] = [];
    let index = 0;
    for await (const part of parts) {
      const buffer = await part.toBuffer();
      const ext = path.extname(part.filename) || ".jpg";
      const filePath = path.join(scanDir, `foto${++index}${ext}`);
      await fs.writeFile(filePath, buffer);
      images.push({ base64: buffer.toString("base64"), mimeType: part.mimetype });
    }

    if (images.length === 0) {
      return reply.code(400).send({ error: "No se recibió ninguna foto" });
    }

    let extraction;
    try {
      extraction = await extractInvoiceFromImages(images);
    } catch (err) {
      request.log.error(err);
      return reply.code(502).send({
        error: "No se pudo interpretar la factura con IA. Puedes cargarla manualmente.",
      });
    }
    // Se deja este log siempre (no solo en error) porque un resultado "exitoso" con
    // items vacíos es indistinguible de un fallo real sin ver qué devolvió Gemini.
    request.log.info({ extraction }, "Extracción de factura con IA");

    const catalogo = await prisma.product.findMany({ where: { activo: true }, include: { categoria: true } });

    const items = await Promise.all(
      extraction.items.map(async (item) => {
        const { product, confianza } = matchProduct(item.descripcion, catalogo);
        let precioVentaSugerido: number | null = null;
        if (product) {
          const margen = await resolveMargin({
            margenOverride: product.margenOverride,
            categoriaMargenDefault: product.categoria?.margenDefault,
          });
          precioVentaSugerido = calcularPrecioVenta(item.precio_unitario, margen);
        }
        return {
          descripcionCruda: item.descripcion,
          cantidad: item.cantidad,
          costoUnitario: item.precio_unitario,
          subtotal: item.subtotal ?? Math.round(item.precio_unitario * item.cantidad * 100) / 100,
          productId: product?.id ?? null,
          nombreProductoSugerido: product?.nombre ?? null,
          precioVentaSugerido,
          confianzaMatch: confianza,
        };
      })
    );

    return {
      scanId,
      fotos: images.map((_, i) => `uploads/purchases/scan-${scanId}/foto${i + 1}`),
      proveedorNombre: extraction.proveedor_nombre ?? null,
      proveedorNit: extraction.proveedor_nit ?? null,
      numeroFactura: extraction.numero_factura ?? null,
      fecha: extraction.fecha ?? null,
      total: extraction.total ?? null,
      confianzaGeneral: extraction.confianza_general,
      items,
    };
  });

  server.post(
    "/purchases",
    { schema: { tags: ["purchases"], body: purchaseCreateSchema } },
    async (request, reply) => {
      const { items, supplierId, numeroFactura, fecha, creadoPorId, scanId } = request.body;

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

      let finalPurchase = purchase;
      if (scanId) {
        const scanDir = path.join(PURCHASE_UPLOADS_DIR, `scan-${scanId}`);
        const finalDir = path.join(PURCHASE_UPLOADS_DIR, purchase.id);
        try {
          await fs.rename(scanDir, finalDir);
          const archivos = await fs.readdir(finalDir);
          const fotos = archivos.map((nombre) => `uploads/purchases/${purchase.id}/${nombre}`);
          finalPurchase = await prisma.purchaseInvoice.update({
            where: { id: purchase.id },
            data: { fotos: JSON.stringify(fotos) },
            include: { items: { include: { product: true } }, supplier: true },
          });
        } catch (err) {
          request.log.warn({ err }, "No se pudieron adjuntar las fotos del escaneo a la compra");
        }
      }

      return reply.code(201).send(finalPurchase);
    }
  );
};
