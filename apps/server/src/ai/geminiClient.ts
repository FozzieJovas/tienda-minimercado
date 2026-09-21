import { GoogleGenAI, ApiError, createUserContent, createPartFromBase64 } from "@google/genai";
import { EXTRACTION_PROMPT, extractInvoiceJsonSchema, type ExtractedInvoice } from "./invoiceSchema.js";

let client: GoogleGenAI | null = null;

function getClient(): GoogleGenAI {
  if (!client) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) throw new Error("Falta configurar GEMINI_API_KEY en el servidor");
    client = new GoogleGenAI({ apiKey });
  }
  return client;
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// La capa gratuita de Gemini devuelve 503 (sobrecarga) o 429 (límite de tasa) con
// cierta frecuencia; son errores transitorios que casi siempre se resuelven reintentando.
async function withRetry<T>(fn: () => Promise<T>, attempts = 3): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await fn();
    } catch (err) {
      const retriable = err instanceof ApiError && (err.status === 503 || err.status === 429);
      if (!retriable || attempt >= attempts) throw err;
      await sleep(1000 * 2 ** (attempt - 1));
    }
  }
}

/** Llama a Gemini con una o varias fotos de una misma factura y devuelve la extracción combinada. */
export async function extractInvoiceFromImages(
  images: { base64: string; mimeType: string }[]
): Promise<ExtractedInvoice> {
  const model = process.env.GEMINI_MODEL ?? "gemini-3.5-flash-lite";
  const ai = getClient();

  const parts = [
    EXTRACTION_PROMPT,
    ...images.map((img) => createPartFromBase64(img.base64, img.mimeType)),
  ];

  const response = await withRetry(() =>
    ai.models.generateContent({
      model,
      contents: createUserContent(parts),
      config: {
        responseMimeType: "application/json",
        // responseSchema espera el tipo Schema propio del SDK (Type.OBJECT, Type.STRING...
        // en mayúsculas); nuestro esquema es JSON Schema estándar, así que va en
        // responseJsonSchema. Usar el campo equivocado no da error: Gemini simplemente
        // ignora el esquema mal tipado y devuelve una extracción vacía en vez de fallar.
        responseJsonSchema: extractInvoiceJsonSchema,
      },
    })
  );

  const text = response.text;
  if (!text) throw new Error("Gemini no devolvió contenido");

  return JSON.parse(text) as ExtractedInvoice;
}
