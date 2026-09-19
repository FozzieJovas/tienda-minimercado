package com.tienda.pos_legacy.data

import com.tienda.pos_legacy.model.Product
import com.tienda.pos_legacy.model.SaleResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class ApiException(message: String) : Exception(message)

class ApiClient(private val prefs: Prefs) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()
    private val jsonMedia = "application/json".toMediaType()

    private fun apiUrl(path: String) = "${prefs.serverUrl}/api$path"

    private suspend fun get(path: String): String = withContext(Dispatchers.IO) {
        val request = Request.Builder().url(apiUrl(path)).get().build()
        client.newCall(request).execute().use { response ->
            val body = response.body?.string() ?: ""
            if (!response.isSuccessful) throw ApiException(extractError(body, response.code))
            body
        }
    }

    private suspend fun post(path: String, jsonBody: JSONObject): String = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(apiUrl(path))
            .post(jsonBody.toString().toRequestBody(jsonMedia))
            .build()
        client.newCall(request).execute().use { response ->
            val body = response.body?.string() ?: ""
            if (!response.isSuccessful) throw ApiException(extractError(body, response.code))
            body
        }
    }

    private fun extractError(body: String, code: Int): String = try {
        JSONObject(body).optString("error", "Error del servidor ($code)")
    } catch (_: Exception) {
        "Error del servidor ($code)"
    }

    suspend fun fetchProducts(search: String?): List<Product> {
        val body = get("/products?activo=true")
        val array = JSONArray(body)
        val all = (0 until array.length()).map { Product.fromJson(array.getJSONObject(it)) }
        if (search.isNullOrBlank()) return all
        val query = search.trim().lowercase()
        return all.filter {
            it.nombre.lowercase().contains(query) || (it.barcode?.contains(query) == true)
        }
    }

    suspend fun createSale(items: List<Pair<Product, Double>>, montoRecibido: Double): SaleResult {
        val itemsJson = JSONArray()
        items.forEach { (product, cantidad) ->
            itemsJson.put(JSONObject().apply {
                put("productId", product.id)
                put("cantidad", cantidad)
            })
        }
        val payload = JSONObject().apply {
            put("medioPago", "EFECTIVO")
            put("montoRecibido", montoRecibido)
            put("items", itemsJson)
        }
        return SaleResult.fromJson(JSONObject(post("/sales", payload)))
    }

    suspend fun fetchSalesToday(): JSONObject = JSONObject(get("/reports/sales-today"))

    suspend fun fetchSettings(): Map<String, String> {
        val obj = JSONObject(get("/settings"))
        return obj.keys().asSequence().associateWith { obj.getString(it) }
    }
}
