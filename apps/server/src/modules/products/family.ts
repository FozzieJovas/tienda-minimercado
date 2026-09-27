import type { Prisma, Product } from "@prisma/client";
import { calcularPrecioVenta, resolveMargin } from "./pricing.js";

type Tx = Prisma.TransactionClient;

export const productInclude = {
  categoria: true,
  presentacionDe: true,
  aliases: { orderBy: { createdAt: "asc" } },
} satisfies Prisma.ProductInclude;

/** Minúsculas, sin tildes ni signos, espacios colapsados: para comparar nombres de factura. */
export function normalizarTexto(texto: string): string {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

/** El stock de una presentación se deriva del producto base; en BD solo lo lleva el base. */
export function conStockDerivado<T extends Product & { presentacionDe?: Product | null }>(p: T): T {
  if (!p.presentacionDe) return p;
  return { ...p, stockActual: Math.floor(p.presentacionDe.stockActual / p.factor) };
}

/** Producto que realmente lleva el stock y cuántas unidades de él equivale 1 de `p`. */
export function duenoDelStock(p: Pick<Product, "id" | "presentacionDeId" | "factor">) {
  return p.presentacionDeId
    ? { id: p.presentacionDeId, factor: p.factor }
    : { id: p.id, factor: 1 };
}

async function actualizarPrecio(tx: Tx, productId: string, costo: number) {
  const p = await tx.product.findUniqueOrThrow({ where: { id: productId }, include: { categoria: true } });
  const margen = await resolveMargin({
    margenOverride: p.margenOverride,
    categoriaMargenDefault: p.categoria?.margenDefault,
  });
  await tx.product.update({
    where: { id: productId },
    data: { costoActual: costo, precioVenta: calcularPrecioVenta(costo, margen) },
  });
}

/**
 * Fija el costo de `productId` y lo propaga a toda su familia (base + presentaciones)
 * en proporción a su factor, recalculando el precio de venta de cada una con su margen.
 * Así, comprar la caja actualiza el precio de la unidad y viceversa.
 */
export async function aplicarCostoFamilia(tx: Tx, productId: string, costo: number) {
  const p = await tx.product.findUniqueOrThrow({ where: { id: productId } });
  const { id: baseId, factor } = duenoDelStock(p);
  const costoUnidad = costo / factor;
  const familia = await tx.product.findMany({
    where: { OR: [{ id: baseId }, { presentacionDeId: baseId }] },
  });
  for (const m of familia) {
    const f = m.id === baseId ? 1 : m.factor;
    await actualizarPrecio(tx, m.id, costoUnidad * f);
  }
}

/** Recalcula el precio de un producto con su costo actual (p. ej. tras cambiar su margen). */
export async function recalcularPrecio(tx: Tx, productId: string) {
  const p = await tx.product.findUniqueOrThrow({ where: { id: productId } });
  await actualizarPrecio(tx, productId, p.costoActual);
}

/**
 * Valida que `presentacionDeId` pueda ser base de `productId`: existe, no es a su vez
 * una presentación (un solo nivel) y `productId` no tiene presentaciones propias.
 * Devuelve el mensaje de error o null.
 */
export async function validarPresentacion(
  tx: Tx,
  productId: string | null,
  presentacionDeId: string,
): Promise<string | null> {
  if (productId === presentacionDeId) return "Un producto no puede ser presentación de sí mismo";
  const base = await tx.product.findUnique({ where: { id: presentacionDeId } });
  if (!base) return "El producto base no existe";
  if (base.presentacionDeId) return "El producto base elegido ya es una presentación de otro producto";
  if (productId) {
    const propias = await tx.product.count({ where: { presentacionDeId: productId } });
    if (propias > 0) return "Este producto ya tiene presentaciones propias; no puede ser presentación de otro";
  }
  return null;
}

/** Guarda `original` como nombre de factura del producto, si no es igual a su nombre. */
export async function guardarAlias(tx: Tx, productId: string, original: string, nombreProducto: string) {
  const texto = normalizarTexto(original);
  if (!texto || texto === normalizarTexto(nombreProducto)) return;
  await tx.productAlias.upsert({
    where: { productId_texto: { productId, texto } },
    create: { productId, texto, original: original.trim() },
    update: {},
  });
}
