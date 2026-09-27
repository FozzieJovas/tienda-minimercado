import type { FastifyPluginAsync } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../../db/client.js";
import { productCreateSchema, productParamsSchema, productUpdateSchema } from "./schemas.js";
import {
  aplicarCostoFamilia,
  conStockDerivado,
  duenoDelStock,
  guardarAlias,
  normalizarTexto,
  productInclude,
  recalcularPrecio,
  validarPresentacion,
} from "./family.js";

async function cargarProducto(id: string) {
  return conStockDerivado(await prisma.product.findUniqueOrThrow({ where: { id }, include: productInclude }));
}

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
      const textoNormalizado = texto ? normalizarTexto(texto) : "";
      const products = await prisma.product.findMany({
        where: {
          ...(activo === undefined ? {} : { activo }),
          ...(favorito === undefined ? {} : { favorito }),
          ...(texto
            ? {
                OR: [
                  { nombre: { contains: texto } },
                  { barcode: { contains: texto } },
                  ...(textoNormalizado
                    ? [{ aliases: { some: { texto: { contains: textoNormalizado } } } }]
                    : []),
                ],
              }
            : {}),
        },
        include: productInclude,
        orderBy: { nombre: "asc" },
      });
      return products.map(conStockDerivado);
    }
  );

  server.get(
    "/products/:id",
    { schema: { tags: ["products"], params: productParamsSchema } },
    async (request, reply) => {
      const product = await prisma.product.findUnique({
        where: { id: request.params.id },
        include: productInclude,
      });
      if (!product) return reply.code(404).send({ error: "Producto no encontrado" });
      return conStockDerivado(product);
    }
  );

  server.get(
    "/products/by-barcode/:barcode",
    { schema: { tags: ["products"], params: z.object({ barcode: z.string() }) } },
    async (request, reply) => {
      const product = await prisma.product.findUnique({
        where: { barcode: request.params.barcode },
        include: productInclude,
      });
      if (!product) return reply.code(404).send({ error: "No hay ningún producto con ese código de barras" });
      return conStockDerivado(product);
    }
  );

  server.post(
    "/products",
    { schema: { tags: ["products"], body: productCreateSchema } },
    async (request, reply) => {
      const { alias, ...data } = request.body;
      if (data.presentacionDeId) {
        const error = await validarPresentacion(prisma, null, data.presentacionDeId);
        if (error) return reply.code(400).send({ error });
      }

      const id = await prisma.$transaction(async (tx) => {
        const created = await tx.product.create({
          data: { ...data, stockActual: data.presentacionDeId ? 0 : data.stockActual },
        });

        if (created.presentacionDeId && data.stockActual) {
          const dueno = duenoDelStock(created);
          await tx.product.update({
            where: { id: dueno.id },
            data: { stockActual: { increment: data.stockActual * dueno.factor } },
          });
        }

        // Una presentación nueva sin costo toma el del producto base multiplicado por su factor.
        let costo = data.costoActual;
        if (created.presentacionDeId && costo === 0) {
          const base = await tx.product.findUniqueOrThrow({ where: { id: created.presentacionDeId } });
          costo = base.costoActual * created.factor;
        }
        await aplicarCostoFamilia(tx, created.id, costo);

        if (alias) await guardarAlias(tx, created.id, alias, created.nombre);
        return created.id;
      });

      return reply.code(201).send(await cargarProducto(id));
    }
  );

  server.patch(
    "/products/:id",
    { schema: { tags: ["products"], params: productParamsSchema, body: productUpdateSchema } },
    async (request, reply) => {
      const existing = await prisma.product.findUnique({ where: { id: request.params.id } });
      if (!existing) return reply.code(404).send({ error: "Producto no encontrado" });

      const { costoActual, stockActual, ...resto } = request.body;
      // null explícito ("dejar de ser presentación") es distinto de no enviarlo (mantener).
      const nuevoBaseId =
        "presentacionDeId" in resto ? (resto.presentacionDeId ?? null) : existing.presentacionDeId;
      const nuevoFactor = resto.factor ?? existing.factor;

      if (nuevoBaseId && nuevoBaseId !== existing.presentacionDeId) {
        const error = await validarPresentacion(prisma, existing.id, nuevoBaseId);
        if (error) return reply.code(400).send({ error });
      }
      const cambioVinculo = nuevoBaseId !== existing.presentacionDeId || nuevoFactor !== existing.factor;

      await prisma.$transaction(async (tx) => {
        await tx.product.update({ where: { id: existing.id }, data: resto });

        // El stock solo se fija directamente en productos base; el de una presentación se deriva.
        if (stockActual !== undefined && !nuevoBaseId) {
          await tx.product.update({ where: { id: existing.id }, data: { stockActual } });
        }

        // Al volverse presentación, el stock que tenía pasa al producto base (en unidades).
        if (nuevoBaseId && !existing.presentacionDeId && existing.stockActual !== 0) {
          const unidades = existing.stockActual * nuevoFactor;
          await tx.product.update({ where: { id: nuevoBaseId }, data: { stockActual: { increment: unidades } } });
          await tx.product.update({ where: { id: existing.id }, data: { stockActual: 0 } });
          await tx.stockMovement.createMany({
            data: [
              { productId: existing.id, tipo: "AJUSTE", cantidadDelta: -existing.stockActual, referenciaTipo: "presentacion-vinculada", referenciaId: nuevoBaseId },
              { productId: nuevoBaseId, tipo: "AJUSTE", cantidadDelta: unidades, referenciaTipo: "presentacion-vinculada", referenciaId: existing.id },
            ],
          });
        }

        if (costoActual !== undefined) {
          await aplicarCostoFamilia(tx, existing.id, costoActual);
        } else if (cambioVinculo && nuevoBaseId) {
          const base = await tx.product.findUniqueOrThrow({ where: { id: nuevoBaseId } });
          await aplicarCostoFamilia(tx, existing.id, base.costoActual * nuevoFactor);
        } else {
          await recalcularPrecio(tx, existing.id);
        }
      });

      return cargarProducto(existing.id);
    }
  );

  server.delete(
    "/products/:id/aliases/:aliasId",
    { schema: { tags: ["products"], params: z.object({ id: z.string(), aliasId: z.string() }) } },
    async (request) => {
      await prisma.productAlias.deleteMany({
        where: { id: request.params.aliasId, productId: request.params.id },
      });
      return cargarProducto(request.params.id);
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

      // cantidadDelta viene en unidades del producto elegido (p. ej. cajas); se aplica al base.
      const { cantidadDelta, tipo, motivo } = request.body;
      const dueno = duenoDelStock(existing);
      const delta = cantidadDelta * dueno.factor;
      await prisma.$transaction([
        prisma.product.update({
          where: { id: dueno.id },
          data: { stockActual: { increment: delta } },
        }),
        prisma.stockMovement.create({
          data: { productId: dueno.id, tipo, cantidadDelta: delta, referenciaTipo: motivo },
        }),
      ]);
      return cargarProducto(existing.id);
    }
  );

  server.delete(
    "/products/:id",
    { schema: { tags: ["products"], params: productParamsSchema } },
    async (request) => {
      await prisma.product.update({
        where: { id: request.params.id },
        data: { activo: false },
      });
      return cargarProducto(request.params.id);
    }
  );
};
