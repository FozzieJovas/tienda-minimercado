-- CreateTable
CREATE TABLE "ProductAlias" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "productId" TEXT NOT NULL,
    "texto" TEXT NOT NULL,
    "original" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ProductAlias_productId_fkey" FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_Product" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "sku" TEXT,
    "barcode" TEXT,
    "nombre" TEXT NOT NULL,
    "categoriaId" TEXT,
    "unidadMedida" TEXT NOT NULL DEFAULT 'unidad',
    "costoActual" REAL NOT NULL DEFAULT 0,
    "precioVenta" REAL NOT NULL DEFAULT 0,
    "margenOverride" REAL,
    "stockActual" REAL NOT NULL DEFAULT 0,
    "stockMinimo" REAL NOT NULL DEFAULT 0,
    "favorito" BOOLEAN NOT NULL DEFAULT false,
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "presentacionDeId" TEXT,
    "factor" REAL NOT NULL DEFAULT 1,
    CONSTRAINT "Product_categoriaId_fkey" FOREIGN KEY ("categoriaId") REFERENCES "Category" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "Product_presentacionDeId_fkey" FOREIGN KEY ("presentacionDeId") REFERENCES "Product" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
INSERT INTO "new_Product" ("activo", "barcode", "categoriaId", "costoActual", "createdAt", "favorito", "id", "margenOverride", "nombre", "precioVenta", "sku", "stockActual", "stockMinimo", "unidadMedida", "updatedAt") SELECT "activo", "barcode", "categoriaId", "costoActual", "createdAt", "favorito", "id", "margenOverride", "nombre", "precioVenta", "sku", "stockActual", "stockMinimo", "unidadMedida", "updatedAt" FROM "Product";
DROP TABLE "Product";
ALTER TABLE "new_Product" RENAME TO "Product";
CREATE UNIQUE INDEX "Product_sku_key" ON "Product"("sku");
CREATE UNIQUE INDEX "Product_barcode_key" ON "Product"("barcode");
CREATE INDEX "Product_categoriaId_idx" ON "Product"("categoriaId");
CREATE INDEX "Product_presentacionDeId_idx" ON "Product"("presentacionDeId");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;

-- CreateIndex
CREATE INDEX "ProductAlias_texto_idx" ON "ProductAlias"("texto");

-- CreateIndex
CREATE UNIQUE INDEX "ProductAlias_productId_texto_key" ON "ProductAlias"("productId", "texto");
