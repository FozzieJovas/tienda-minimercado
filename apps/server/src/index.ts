import Fastify from "fastify";
import cors from "@fastify/cors";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";
import {
  jsonSchemaTransform,
  serializerCompiler,
  validatorCompiler,
} from "fastify-type-provider-zod";
import { productRoutes } from "./modules/products/routes.js";
import { categoryRoutes } from "./modules/categories/routes.js";
import { settingsRoutes } from "./modules/settings/routes.js";
import { saleRoutes } from "./modules/sales/routes.js";
import { purchaseRoutes } from "./modules/purchases/routes.js";
import { reportRoutes } from "./modules/reports/routes.js";

const PORT = Number(process.env.PORT ?? 4000);
const HOST = process.env.HOST ?? "0.0.0.0";

async function main() {
  const app = Fastify({ logger: true });

  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);

  await app.register(cors, { origin: true });

  await app.register(swagger, {
    openapi: { info: { title: "Tienda API", version: "0.1.0" } },
    transform: jsonSchemaTransform,
  });
  await app.register(swaggerUi, { routePrefix: "/docs" });

  app.get("/health", async () => ({ status: "ok" }));

  await app.register(async (api) => {
    await api.register(productRoutes);
    await api.register(categoryRoutes);
    await api.register(settingsRoutes);
    await api.register(saleRoutes);
    await api.register(purchaseRoutes);
    await api.register(reportRoutes);
  }, { prefix: "/api" });

  await app.listen({ port: PORT, host: HOST });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
