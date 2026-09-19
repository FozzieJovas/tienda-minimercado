package com.tienda.pos_legacy.ui.screens

import android.annotation.SuppressLint
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.tienda.pos_legacy.data.Prefs
import com.tienda.pos_legacy.printing.BluetoothPrinter

@SuppressLint("MissingPermission")
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(prefs: Prefs, printer: BluetoothPrinter, onBack: () -> Unit) {
    var url by remember { mutableStateOf(prefs.serverUrl) }
    var selectedMac by remember { mutableStateOf(prefs.printerMac) }
    var devices by remember { mutableStateOf(printer.pairedDevices()) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Configuración") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Volver") }
                },
            )
        },
    ) { padding ->
        LazyColumn(modifier = Modifier.padding(padding).padding(16.dp)) {
            item {
                Text("Servidor")
                TextField(value = url, onValueChange = { url = it }, modifier = Modifier.fillMaxWidth())
                Button(onClick = { prefs.serverUrl = url.trim() }) { Text("Guardar URL") }

                Text("Impresora Bluetooth", modifier = Modifier.padding(top = 24.dp))
                Button(onClick = { devices = printer.pairedDevices() }) { Text("Buscar impresoras emparejadas") }
            }
            items(devices) { device ->
                Row {
                    RadioButton(
                        selected = device.address == selectedMac,
                        onClick = {
                            selectedMac = device.address
                            prefs.printerMac = device.address
                        },
                    )
                    Text("${device.name} (${device.address})")
                }
            }
        }
    }
}
