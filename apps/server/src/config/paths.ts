import path from "node:path";

export const DATA_DIR = path.join(process.cwd(), "data");
export const PURCHASE_UPLOADS_DIR = path.join(DATA_DIR, "uploads", "purchases");
