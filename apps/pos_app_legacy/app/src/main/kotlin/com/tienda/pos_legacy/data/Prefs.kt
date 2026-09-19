package com.tienda.pos_legacy.data

import android.content.Context

class Prefs(context: Context) {
    private val prefs = context.getSharedPreferences("tienda_pos", Context.MODE_PRIVATE)

    var serverUrl: String
        get() = prefs.getString(KEY_SERVER_URL, DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL
        set(value) = prefs.edit().putString(KEY_SERVER_URL, value).apply()

    var printerMac: String?
        get() = prefs.getString(KEY_PRINTER_MAC, null)
        set(value) = prefs.edit().putString(KEY_PRINTER_MAC, value).apply()

    companion object {
        private const val KEY_SERVER_URL = "server_url"
        private const val KEY_PRINTER_MAC = "printer_mac"
        const val DEFAULT_SERVER_URL = "http://tienda.local:4000"
    }
}
