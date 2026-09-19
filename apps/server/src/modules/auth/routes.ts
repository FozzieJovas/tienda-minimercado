import type { FastifyPluginAsync } from "fastify";
import type { ZodTypeProvider } from "fastify-type-provider-zod";
import { z } from "zod";
import { prisma } from "../../db/client.js";
import { verifyPassword } from "./password.js";

const loginSchema = z.object({
  usuario: z.string().min(1),
  password: z.string().min(1),
});

export const authRoutes: FastifyPluginAsync = async (app) => {
  const server = app.withTypeProvider<ZodTypeProvider>();

  server.post(
    "/auth/login",
    { schema: { tags: ["auth"], body: loginSchema } },
    async (request, reply) => {
      const { usuario, password } = request.body;
      const user = await prisma.user.findUnique({ where: { usuario } });
      if (!user || !user.activo || !verifyPassword(password, user.passwordHash)) {
        return reply.code(401).send({ error: "Usuario o contraseña incorrectos" });
      }
      return { id: user.id, nombre: user.nombre, usuario: user.usuario, rol: user.rol };
    }
  );
};
