import { prisma } from "../../db/client.js";

const GLOBAL_MARGIN_KEY = "margen_default";
const DEFAULT_GLOBAL_MARGIN = 0.3;

/**
 * Jerarquía de margen: override de producto > margen de categoría > margen global.
 * El margen se expresa como fracción (0.3 = 30%) aplicada sobre el costo.
 */
export async function resolveMargin(params: {
  margenOverride: number | null | undefined;
  categoriaMargenDefault: number | null | undefined;
}): Promise<number> {
  if (params.margenOverride != null) return params.margenOverride;
  if (params.categoriaMargenDefault != null) return params.categoriaMargenDefault;

  const setting = await prisma.setting.findUnique({ where: { clave: GLOBAL_MARGIN_KEY } });
  if (setting) {
    const parsed = Number(setting.valor);
    if (!Number.isNaN(parsed)) return parsed;
  }
  return DEFAULT_GLOBAL_MARGIN;
}

// Precios en pesos colombianos no manejan centavos; se redondea siempre hacia
// arriba a la centena (ej. 2475 -> 2500) para que el precio final sea "redondo".
const REDONDEO = 100;

export function calcularPrecioVenta(costo: number, margen: number): number {
  const crudo = costo * (1 + margen);
  return Math.ceil(crudo / REDONDEO) * REDONDEO;
}
