package com.tienda.pos_legacy.model

import org.json.JSONObject

data class SaleItemResult(
    val productId: String,
    val nombreProducto: String,
    val cantidad: Double,
    val precioUnitario: Double,
    val subtotal: Double,
) {
    companion object {
        fun fromJson(json: JSONObject): SaleItemResult {
            val product = json.optJSONObject("product")
            return SaleItemResult(
                productId = json.getString("productId"),
                nombreProducto = product?.optString("nombre") ?: "",
                cantidad = json.getDouble("cantidad"),
                precioUnitario = json.getDouble("precioUnitario"),
                subtotal = json.getDouble("subtotal"),
            )
        }
    }
}

data class SaleResult(
    val id: String,
    val numeroTicket: Int,
    val total: Double,
    val montoRecibido: Double?,
    val cambio: Double?,
    val fecha: String,
    val items: List<SaleItemResult>,
) {
    companion object {
        fun fromJson(json: JSONObject): SaleResult {
            val itemsJson = json.getJSONArray("items")
            val items = (0 until itemsJson.length()).map { SaleItemResult.fromJson(itemsJson.getJSONObject(it)) }
            return SaleResult(
                id = json.getString("id"),
                numeroTicket = json.getInt("numeroTicket"),
                total = json.getDouble("total"),
                montoRecibido = if (json.isNull("montoRecibido")) null else json.getDouble("montoRecibido"),
                cambio = if (json.isNull("cambio")) null else json.getDouble("cambio"),
                fecha = json.getString("fecha"),
                items = items,
            )
        }
    }
}
