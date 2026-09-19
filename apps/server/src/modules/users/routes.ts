import type { FastifyPluginAsync } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../../db/client.js";
import { userCreateSchema, userUpdateSchema } from "./schemas.js";
import { hashPassword } from "../auth/password.js";

function toPublicUser(user: { id: string; nombre: string; usuario: string; rol: string; activo: boolean }) {
  return { id: user.id, nombre: user.nombre, usuario: user.usuario, rol: user.rol, activo: user.activo };
}

export const userRoutes: FastifyPluginAsync = async (app) => {
  const server = app.withTypeProvider<ZodTypeProvider>();

  server.get("/users", { schema: { tags: ["users"] } }, async () => {
    const users = await prisma.user.findMany({ orderBy: { nombre: "asc" } });
    return users.map(toPublicUser);
  });

  server.post(
    "/users",
    { schema: { tags: ["users"], body: userCreateSchema } },
    async (request, reply) => {
      const { password, ...data } = request.body;
      const existing = await prisma.user.findUnique({ where: { usuario: data.usuario } });
      if (existing) return reply.code(400).send({ error: "Ese nombre de usuario ya existe" });

      const user = await prisma.user.create({
        data: { ...data, passwordHash: hashPassword(password) },
      });
      return reply.code(201).send(toPublicUser(user));
    }
  );

  server.patch(
    "/users/:id",
    { schema: { tags: ["users"], params: z.object({ id: z.string() }), body: userUpdateSchema } },
    async (request, reply) => {
      const { password, ...data } = request.body;
      const user = await prisma.user.update({
        where: { id: request.params.id },
        data: {
          ...data,
          ...(password ? { passwordHash: hashPassword(password) } : {}),
        },
      });
      return toPublicUser(user);
    }
  );
};
