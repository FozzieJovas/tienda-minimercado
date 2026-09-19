import { distance } from "fastest-levenshtein";
import type { Product, Category } from "@prisma/client";

export type ProductWithCategoria = Product & { categoria: Category | null };

export type MatchConfidence = "alta" | "media" | "baja" | null;

export interface ProductMatch {
  product: ProductWithCategoria | null;
  confianza: MatchConfidence;
}

function similarity(a: string, b: string): number {
  const maxLen = Math.max(a.length, b.length);
  if (maxLen === 0) return 1;
  return 1 - distance(a.toLowerCase(), b.toLowerCase()) / maxLen;
}

/** Empareja una descripción cruda de factura contra el catálogo por nombre (similitud de texto). */
export function matchProduct(descripcion: string, catalogo: ProductWithCategoria[]): ProductMatch {
  let best: ProductWithCategoria | null = null;
  let bestScore = 0;

  for (const product of catalogo) {
    const score = similarity(descripcion, product.nombre);
    if (score > bestScore) {
      bestScore = score;
      best = product;
    }
  }

  if (bestScore >= 0.75) return { product: best, confianza: "alta" };
  if (bestScore >= 0.45) return { product: best, confianza: "media" };
  return { product: null, confianza: "baja" };
}
