package com.tienda.pos_legacy.ui

import androidx.compose.runtime.mutableStateMapOf
import com.tienda.pos_legacy.model.Product

class CartLine(val product: Product, var cantidad: Double) {
    val subtotal: Double get() = product.precioVenta * cantidad
}

/** Estado del carrito respaldado por un mapa observable de Compose (sin dependencias externas). */
class Cart {
    private val _lines = mutableStateMapOf<String, CartLine>()
    val lines: List<CartLine> get() = _lines.values.toList()
    val total: Double get() = _lines.values.sumOf { it.subtotal }
    val isEmpty: Boolean get() = _lines.isEmpty()

    fun add(product: Product) {
        val existing = _lines[product.id]
        if (existing != null) {
            _lines[product.id] = CartLine(product, existing.cantidad + 1)
        } else {
            _lines[product.id] = CartLine(product, 1.0)
        }
    }

    fun setCantidad(productId: String, cantidad: Double) {
        if (cantidad <= 0) {
            _lines.remove(productId)
        } else {
            _lines[productId]?.let { _lines[productId] = CartLine(it.product, cantidad) }
        }
    }

    fun clear() = _lines.clear()

    fun toApiItems(): List<Pair<Product, Double>> = _lines.values.map { it.product to it.cantidad }
}
