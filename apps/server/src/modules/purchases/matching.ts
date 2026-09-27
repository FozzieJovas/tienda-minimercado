import { distance } from "fastest-levenshtein";
import type { Product, Category, ProductAlias } from "@prisma/client";
import { normalizarTexto } from "../products/family.js";

export type ProductWithCategoria = Product & { categoria: Category | null; aliases: ProductAlias[] };

export type MatchConfidence = "alta" | "media" | "baja" | null;

export interface ProductMatch {
  product: ProductWithCategoria | null;
  confianza: MatchConfidence;
}

function similarity(a: string, b: string): number {
  const maxLen = Math.max(a.length, b.length);
  if (maxLen === 0) return 1;
  return 1 - distance(a, b) / maxLen;
}

/**
 * Empareja una descripción cruda de factura contra el catálogo. Primero busca un
 * nombre de factura ya aprendido (alias) idéntico; si no hay, compara por similitud
 * de texto contra el nombre de venta y los alias de cada producto.
 */
export function matchProduct(descripcion: string, catalogo: ProductWithCategoria[]): ProductMatch {
  const texto = normalizarTexto(descripcion);

  // Si el mismo nombre de factura se ha ligado a varios productos, gana el más reciente.
  let aliasExacto: { product: ProductWithCategoria; fecha: Date } | null = null;
  for (const product of catalogo) {
    for (const alias of product.aliases) {
      if (alias.texto === texto && (!aliasExacto || alias.createdAt > aliasExacto.fecha)) {
        aliasExacto = { product, fecha: alias.createdAt };
      }
    }
  }
  if (aliasExacto) return { product: aliasExacto.product, confianza: "alta" };

  let best: ProductWithCategoria | null = null;
  let bestScore = 0;
  for (const product of catalogo) {
    const candidatos = [normalizarTexto(product.nombre), ...product.aliases.map((a) => a.texto)];
    for (const candidato of candidatos) {
      const score = similarity(texto, candidato);
      if (score > bestScore) {
        bestScore = score;
        best = product;
      }
    }
  }

  if (bestScore >= 0.75) return { product: best, confianza: "alta" };
  if (bestScore >= 0.45) return { product: best, confianza: "media" };
  return { product: null, confianza: "baja" };
}
