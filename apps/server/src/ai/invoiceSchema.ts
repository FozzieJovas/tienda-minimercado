export interface ExtractedInvoiceItem {
  descripcion: string;
  cantidad: number;
  precio_unitario: number;
  subtotal?: number;
}

export interface ExtractedInvoice {
  proveedor_nombre?: string;
  proveedor_nit?: string;
  numero_factura?: string;
  fecha?: string;
  items: ExtractedInvoiceItem[];
  total?: number;
  confianza_general: "alta" | "media" | "baja";
}

export const extractInvoiceJsonSchema = {
  type: "object",
  properties: {
    proveedor_nombre: { type: "string" },
    proveedor_nit: { type: "string" },
    numero_factura: { type: "string" },
    fecha: { type: "string", description: "Fecha de la factura en formato YYYY-MM-DD si se puede determinar" },
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          descripcion: { type: "string" },
          cantidad: { type: "number" },
          precio_unitario: { type: "number" },
          subtotal: { type: "number" },
        },
        required: ["descripcion", "cantidad", "precio_unitario"],
      },
    },
    total: { type: "number" },
    confianza_general: { type: "string", enum: ["alta", "media", "baja"] },
  },
  required: ["items", "confianza_general"],
};

export const EXTRACTION_PROMPT = `Eres un asistente que lee facturas o remisiones de compra de un minimercado en Colombia, muchas veces fotografiadas de papel térmico o con mala calidad.
Extrae del documento: nombre y NIT del proveedor si aparecen, número de factura, fecha, y la lista de ítems comprados con su descripción, cantidad y precio unitario (y subtotal si aparece explícito).
Si un dato no aparece o no se puede leer con confianza, omítelo en vez de inventarlo.
Responde únicamente con el JSON que cumple el esquema indicado.`;
