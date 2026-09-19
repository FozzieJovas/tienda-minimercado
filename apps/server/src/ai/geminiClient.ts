import { GoogleGenAI, createUserContent, createPartFromBase64 } from "@google/genai";
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

/** Llama a Gemini con una o varias fotos de una misma factura y devuelve la extracción combinada. */
export async function extractInvoiceFromImages(
  images: { base64: string; mimeType: string }[]
): Promise<ExtractedInvoice> {
  const model = process.env.GEMINI_MODEL ?? "gemini-flash-latest";
  const ai = getClient();

  const parts = [
    EXTRACTION_PROMPT,
    ...images.map((img) => createPartFromBase64(img.base64, img.mimeType)),
  ];

  const response = await ai.models.generateContent({
    model,
    contents: createUserContent(parts),
    config: {
      responseMimeType: "application/json",
      responseSchema: extractInvoiceJsonSchema,
    },
  });

  const text = response.text;
  if (!text) throw new Error("Gemini no devolvió contenido");

  return JSON.parse(text) as ExtractedInvoice;
}
