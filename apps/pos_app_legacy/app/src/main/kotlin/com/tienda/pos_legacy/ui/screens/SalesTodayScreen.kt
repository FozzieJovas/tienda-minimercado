package com.tienda.pos_legacy.ui.screens

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.tienda.pos_legacy.data.ApiClient
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale

private val currency = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("es-CO")).apply {
    maximumFractionDigits = 0
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SalesTodayScreen(api: ApiClient, onBack: () -> Unit) {
    var report by remember { mutableStateOf<JSONObject?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var refreshKey by remember { mutableStateOf(0) }

    LaunchedEffect(refreshKey) {
        try {
            report = api.fetchSalesToday()
        } catch (_: Exception) {
            error = "No se pudo cargar el reporte"
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Ventas de hoy") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Volver") }
                },
                actions = {
                    IconButton(onClick = { refreshKey++ }) { Icon(Icons.Filled.Refresh, contentDescription = "Actualizar") }
                },
            )
        },
    ) { padding ->
        when {
            error != null -> Text(error!!, modifier = Modifier.padding(padding).padding(16.dp))
            report == null -> CircularProgressIndicator(modifier = Modifier.padding(padding).padding(16.dp))
            else -> {
                val ventas = report!!.getJSONArray("ventas")
                val porMedioPago = report!!.getJSONObject("porMedioPago")
                LazyColumn(modifier = Modifier.fillMaxSize().padding(padding)) {
                    item {
                        Text(
                            "Total del día: ${currency.format(report!!.getDouble("totalGeneral"))}",
                            modifier = Modifier.padding(16.dp),
                        )
                        Text("${report!!.getInt("cantidadVentas")} ventas", modifier = Modifier.padding(horizontal = 16.dp))
                    }
                    items(porMedioPago.keys().asSequence().toList()) { medio ->
                        val bucket = porMedioPago.getJSONObject(medio)
                        ListItem(
                            headlineContent = { Text(medio) },
                            trailingContent = { Text(currency.format(bucket.getDouble("total"))) },
                            supportingContent = { Text("${bucket.getInt("cantidadVentas")} ventas") },
                        )
                    }
                    items(ventas.length()) { index ->
                        val venta = ventas.getJSONObject(index)
                        ListItem(
                            headlineContent = { Text("#${venta.getInt("numeroTicket")}") },
                            supportingContent = { Text(venta.getString("medioPago")) },
                            trailingContent = { Text(currency.format(venta.getDouble("total"))) },
                        )
                    }
                }
            }
        }
    }
}
