package com.tienda.pos_legacy.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.text.input.KeyboardType
import com.tienda.pos_legacy.data.ApiClient
import com.tienda.pos_legacy.data.ApiException
import com.tienda.pos_legacy.model.SaleResult
import com.tienda.pos_legacy.ui.Cart
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.util.Locale

private val currency = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("es-CO")).apply {
    maximumFractionDigits = 0
}

@Composable
fun CheckoutDialog(
    cart: Cart,
    api: ApiClient,
    onDismiss: () -> Unit,
    onSaleCompleted: (SaleResult) -> Unit,
) {
    var montoTexto by remember { mutableStateOf("") }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    val total = cart.total
    val montoRecibido = montoTexto.toDoubleOrNull() ?: 0.0
    val cambio = (montoRecibido - total).coerceAtLeast(0.0)

    AlertDialog(
        onDismissRequest = { if (!submitting) onDismiss() },
        title = { Text("Cobrar (efectivo)") },
        text = {
            Column {
                Text("Total: ${currency.format(total)}")
                TextField(
                    value = montoTexto,
                    onValueChange = { montoTexto = it.filter(Char::isDigit) },
                    label = { Text("Monto recibido") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                )
                Text("Cambio: ${currency.format(cambio)}")
                error?.let { Text(it) }
            }
        },
        confirmButton = {
            if (submitting) {
                CircularProgressIndicator()
            } else {
                Button(onClick = {
                    if (montoRecibido < total) {
                        error = "El monto recibido es menor al total"
                        return@Button
                    }
                    submitting = true
                    error = null
                    scope.launch {
                        try {
                            val sale = api.createSale(cart.toApiItems(), montoRecibido)
                            onSaleCompleted(sale)
                        } catch (e: ApiException) {
                            error = e.message
                            submitting = false
                        } catch (_: Exception) {
                            error = "No se pudo conectar con el servidor"
                            submitting = false
                        }
                    }
                }) { Text("Confirmar venta") }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, enabled = !submitting) { Text("Cancelar") }
        },
    )
}
