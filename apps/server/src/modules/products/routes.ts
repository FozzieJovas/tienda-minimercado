import type { FastifyPluginAsync } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../../db/client.js";
import { productCreateSchema, productParamsSchema, productUpdateSchema } from "./schemas.js";
import { calcularPrecioVenta, resolveMargin } from "./pricing.js";

export const productRoutes: FastifyPluginAsync = async (app) => {
  const server = app.withTypeProvider<ZodTypeProvider>();

  server.get(
    "/products",
    {
      schema: {
        tags: ["products"],
        querystring: z.object({
          activo: z.coerce.boolean().optional(),
          favorito: z.coerce.boolean().optional(),
          search: z.string().optional(),
        }),
      },
    },
    async (request) => {
      const { activo, favorito, search } = request.query;
      const texto = search?.trim();
      return prisma.product.findMany({
        where: {
          ...(activo === undefined ? {} : { activo }),
          ...(favorito === undefined ? {} : { favorito }),
          ...(texto
            ? { OR: [{ nombre: { contains: texto } }, { barcode: { contains: texto } }] }
            : {}),
        },
        include: { categoria: true },
        orderBy: { nombre: "asc" },
      });
    }
  );

  server.get(
    "/products/:id",
    { schema: { tags: ["products"], params: productParamsSchema } },
    async (request, reply) => {
      const product = await prisma.product.findUnique({
        where: { id: request.params.id },
        include: { categoria: true },
      });
      if (!product) return reply.code(404).send({ error: "Producto no encontrado" });
      return product;
    }
  );

  server.get(
    "/products/by-barcode/:barcode",
    { schema: { tags: ["products"], params: z.object({ barcode: z.string() }) } },
    async (request, reply) => {
      const product = await prisma.product.findUnique({
        where: { barcode: request.params.barcode },
        include: { categoria: true },
      });
      if (!product) return reply.code(404).send({ error: "No hay ningún producto con ese código de barras" });
      return product;
    }
  );

  server.post(
    "/products",
    { schema: { tags: ["products"], body: productCreateSchema } },
    async (request, reply) => {
      const data = request.body;
      const categoria = data.categoriaId
        ? await prisma.category.findUnique({ where: { id: data.categoriaId } })
        : null;
      const margen = await resolveMargin({
        margenOverride: data.margenOverride,
        categoriaMargenDefault: categoria?.margenDefault,
      });
      const product = await prisma.product.create({
        data: {
          ...data,
          precioVenta: calcularPrecioVenta(data.costoActual, margen),
        },
      });
      return reply.code(201).send(product);
    }
  );

  server.patch(
    "/products/:id",
    { schema: { tags: ["products"], params: productParamsSchema, body: productUpdateSchema } },
    async (request, reply) => {
      const existing = await prisma.product.findUnique({ where: { id: request.params.id } });
      if (!existing) return reply.code(404).send({ error: "Producto no encontrado" });

      const data = request.body;
      // Mismo motivo que margenOverride abajo: null explícito es "quitar categoría".
      const categoriaId = "categoriaId" in data ? data.categoriaId : existing.categoriaId;
      const categoria = categoriaId
        ? await prisma.category.findUnique({ where: { id: categoriaId } })
        : null;
      const costoActual = data.costoActual ?? existing.costoActual;
      // "margenOverride" en null es explícito ("quitar el override"), distinto de
      // no enviarlo (mantener el actual) -- por eso no se puede usar `??` aquí.
      const margenOverride = "margenOverride" in data ? data.margenOverride : existing.margenOverride;
      const margen = await resolveMargin({
        margenOverride,
        categoriaMargenDefault: categoria?.margenDefault,
      });

      const product = await prisma.product.update({
        where: { id: request.params.id },
        data: {
          ...data,
          precioVenta: calcularPrecioVenta(costoActual, margen),
        },
      });
      return product;
    }
  );

  server.post(
    "/products/:id/stock-adjustment",
    {
      schema: {
        tags: ["products"],
        params: productParamsSchema,
        body: z.object({
          cantidadDelta: z.number().refine((v) => v !== 0, "cantidadDelta no puede ser 0"),
          tipo: z.enum(["AJUSTE", "MERMA"]).default("AJUSTE"),
          motivo: z.string().optional(),
        }),
      },
    },
    async (request, reply) => {
      const existing = await prisma.product.findUnique({ where: { id: request.params.id } });
      if (!existing) return reply.code(404).send({ error: "Producto no encontrado" });

      const { cantidadDelta, tipo, motivo } = request.body;
      const [product] = await prisma.$transaction([
        prisma.product.update({
          where: { id: request.params.id },
          data: { stockActual: { increment: cantidadDelta } },
        }),
        prisma.stockMovement.create({
          data: {
            productId: request.params.id,
            tipo,
            cantidadDelta,
            referenciaTipo: motivo,
          },
        }),
      ]);
      return product;
    }
  );

  server.delete(
    "/products/:id",
    { schema: { tags: ["products"], params: productParamsSchema } },
    async (request) => {
      const product = await prisma.product.update({
        where: { id: request.params.id },
        data: { activo: false },
      });
      return product;
    }
  );
};
