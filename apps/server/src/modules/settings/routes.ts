import type { FastifyPluginAsync } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../../db/client.js";

export const settingsRoutes: FastifyPluginAsync = async (app) => {
  const server = app.withTypeProvider<ZodTypeProvider>();

  server.get("/settings", { schema: { tags: ["settings"] } }, async () => {
    const settings = await prisma.setting.findMany();
    return Object.fromEntries(settings.map((s) => [s.clave, s.valor]));
  });

  server.put(
    "/settings/:clave",
    {
      schema: {
        tags: ["settings"],
        params: z.object({ clave: z.string() }),
        body: z.object({ valor: z.string() }),
      },
    },
    async (request) => {
      return prisma.setting.upsert({
        where: { clave: request.params.clave },
        create: { clave: request.params.clave, valor: request.body.valor },
        update: { valor: request.body.valor },
      });
    }
  );
};
