package com.tienda.pos_legacy.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.RemoveCircle
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.tienda.pos_legacy.data.ApiClient
import com.tienda.pos_legacy.data.Prefs
import com.tienda.pos_legacy.model.Product
import com.tienda.pos_legacy.printing.BluetoothPrinter
import com.tienda.pos_legacy.printing.TicketBuilder
import com.tienda.pos_legacy.ui.Cart
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.util.Locale

private val currency = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("es-CO")).apply {
    maximumFractionDigits = 0
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PosScreen(
    api: ApiClient,
    prefs: Prefs,
    printer: BluetoothPrinter,
    onOpenVentasHoy: () -> Unit,
    onOpenConfiguracion: () -> Unit,
) {
    val cart = remember { Cart() }
    var products by remember { mutableStateOf<List<Product>>(emptyList()) }
    var search by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var showCheckout by remember { mutableStateOf(false) }
    var refreshKey by remember { mutableStateOf(0) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(search, refreshKey) {
        loading = true
        error = null
        try {
            products = api.fetchProducts(search)
        } catch (_: Exception) {
            error = "No se pudo conectar con el servidor. Revisa la configuración."
        }
        loading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Punto de venta") },
                actions = {
                    IconButton(onClick = onOpenVentasHoy) {
                        Icon(Icons.Filled.BarChart, contentDescription = "Ventas de hoy")
                    }
                    IconButton(onClick = onOpenConfiguracion) {
                        Icon(Icons.Filled.Settings, contentDescription = "Configuración")
                    }
                },
            )
        },
    ) { padding ->
        Row(modifier = Modifier.fillMaxSize().padding(padding)) {
            Column(modifier = Modifier.weight(3f).padding(8.dp)) {
                TextField(
                    value = search,
                    onValueChange = { search = it },
                    label = { Text("Buscar por nombre o código de barras") },
                    modifier = Modifier.fillMaxWidth(),
                )
                when {
                    loading -> CircularProgressIndicator(modifier = Modifier.padding(16.dp))
                    error != null -> Text(error!!, modifier = Modifier.padding(16.dp))
                    products.isEmpty() -> Text("Sin productos", modifier = Modifier.padding(16.dp))
                    else -> LazyColumn {
                        items(products) { product ->
                            ListItem(
                                headlineContent = { Text(product.nombre) },
                                supportingContent = { Text("Stock: ${product.stockActual.toInt()}") },
                                trailingContent = { Text(currency.format(product.precioVenta)) },
                                modifier = Modifier.fillMaxWidth(),
                            )
                            HorizontalDivider()
                        }
                    }
                }
            }
            Column(modifier = Modifier.weight(2f).padding(8.dp)) {
                Text("Carrito", style = androidx.compose.material3.MaterialTheme.typography.titleMedium)
                if (cart.isEmpty) {
                    Text("Carrito vacío", modifier = Modifier.padding(16.dp))
                } else {
                    LazyColumn(modifier = Modifier.weight(1f)) {
                        items(cart.lines) { line ->
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(line.product.nombre)
                                    Row {
                                        IconButton(onClick = {
                                            cart.setCantidad(line.product.id, line.cantidad - 1)
                                            refreshKey++
                                        }) { Icon(Icons.Filled.RemoveCircle, contentDescription = "Restar") }
                                        Text(line.cantidad.toInt().toString())
                                        IconButton(onClick = {
                                            cart.setCantidad(line.product.id, line.cantidad + 1)
                                            refreshKey++
                                        }) { Icon(Icons.Filled.AddCircle, contentDescription = "Sumar") }
                                    }
                                }
                                Text(currency.format(line.subtotal))
                            }
                        }
                    }
                }
                HorizontalDivider()
                Row(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Total", style = androidx.compose.material3.MaterialTheme.typography.titleLarge)
                    Text(currency.format(cart.total), style = androidx.compose.material3.MaterialTheme.typography.titleLarge)
                }
                Button(
                    onClick = { showCheckout = true },
                    enabled = !cart.isEmpty,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Cobrar") }
            }
        }
    }

    if (showCheckout) {
        CheckoutDialog(
            cart = cart,
            api = api,
            onDismiss = { showCheckout = false },
            onSaleCompleted = { sale ->
                showCheckout = false
                scope.launch {
                    cart.clear()
                    refreshKey++
                    val printerMac = prefs.printerMac
                    if (printerMac != null) {
                        try {
                            val settingsMap = api.fetchSettings()
                            val bytes = TicketBuilder.build(
                                sale = sale,
                                nombreTienda = settingsMap["nombre_tienda"] ?: "Mi Tienda",
                                piePagina = settingsMap["pie_ticket"],
                            )
                            printer.printBytes(printerMac, bytes)
                        } catch (_: Exception) {
                            // La venta ya quedó registrada; si falla la impresión se puede reintentar
                            // manualmente desde configuración. No revertimos la venta por esto.
                        }
                    }
                }
            },
        )
    }
}
