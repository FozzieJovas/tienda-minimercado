package com.tienda.pos_legacy.model

import org.json.JSONObject

data class Product(
    val id: String,
    val nombre: String,
    val barcode: String?,
    val precioVenta: Double,
    val stockActual: Double,
) {
    companion object {
        fun fromJson(json: JSONObject): Product = Product(
            id = json.getString("id"),
            nombre = json.getString("nombre"),
            barcode = if (json.isNull("barcode")) null else json.getString("barcode"),
            precioVenta = json.getDouble("precioVenta"),
            stockActual = json.getDouble("stockActual"),
        )
    }
}
