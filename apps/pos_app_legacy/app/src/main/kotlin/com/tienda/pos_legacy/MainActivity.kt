package com.tienda.pos_legacy

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.tienda.pos_legacy.data.ApiClient
import com.tienda.pos_legacy.data.Prefs
import com.tienda.pos_legacy.printing.BluetoothPrinter
import com.tienda.pos_legacy.ui.screens.PosScreen
import com.tienda.pos_legacy.ui.screens.SalesTodayScreen
import com.tienda.pos_legacy.ui.screens.SettingsScreen

enum class Screen { POS, VENTAS_HOY, CONFIGURACION }

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val prefs = remember { Prefs(applicationContext) }
            val api = remember { ApiClient(prefs) }
            val printer = remember { BluetoothPrinter() }
            MaterialTheme {
                Surface {
                    App(prefs = prefs, api = api, printer = printer)
                }
            }
        }
    }
}

@Composable
private fun App(prefs: Prefs, api: ApiClient, printer: BluetoothPrinter) {
    var screen by remember { mutableStateOf(Screen.POS) }

    when (screen) {
        Screen.POS -> PosScreen(
            api = api,
            prefs = prefs,
            printer = printer,
            onOpenVentasHoy = { screen = Screen.VENTAS_HOY },
            onOpenConfiguracion = { screen = Screen.CONFIGURACION },
        )
        Screen.VENTAS_HOY -> SalesTodayScreen(api = api, onBack = { screen = Screen.POS })
        Screen.CONFIGURACION -> SettingsScreen(
            prefs = prefs,
            printer = printer,
            onBack = { screen = Screen.POS },
        )
    }
}
