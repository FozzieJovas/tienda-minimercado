import type { FastifyPluginAsync } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../../db/client.js";

const categorySchema = z.object({
  nombre: z.string().min(1),
  margenDefault: z.number().min(-1).optional(),
});

export const categoryRoutes: FastifyPluginAsync = async (app) => {
  const server = app.withTypeProvider<ZodTypeProvider>();

  server.get("/categories", { schema: { tags: ["categories"] } }, async () => {
    return prisma.category.findMany({ orderBy: { nombre: "asc" } });
  });

  server.post(
    "/categories",
    { schema: { tags: ["categories"], body: categorySchema } },
    async (request, reply) => {
      const category = await prisma.category.create({ data: request.body });
      return reply.code(201).send(category);
    }
  );

  server.patch(
    "/categories/:id",
    {
      schema: {
        tags: ["categories"],
        params: z.object({ id: z.string() }),
        body: categorySchema.partial(),
      },
    },
    async (request) => {
      return prisma.category.update({
        where: { id: request.params.id },
        data: request.body,
      });
    }
  );
};
