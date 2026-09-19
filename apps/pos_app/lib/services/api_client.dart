import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/sale.dart';
import 'settings_service.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  final SettingsService _settings;

  ApiClient(this._settings);

  Future<Uri> _uri(String path) async {
    final base = await _settings.getServerUrl();
    return Uri.parse('$base/api$path');
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final message = (body is Map && body['error'] != null)
          ? body['error'].toString()
          : 'Error del servidor (${response.statusCode})';
      throw ApiException(message);
    }
    return body as Map<String, dynamic>;
  }

  Future<List<Product>> fetchProducts({String? search}) async {
    final uri = await _uri('/products?activo=true');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode >= 400) {
      throw ApiException('No se pudo cargar el catálogo (${response.statusCode})');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    final products = list
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
    if (search == null || search.trim().isEmpty) return products;
    final query = search.trim().toLowerCase();
    return products
        .where((p) =>
            p.nombre.toLowerCase().contains(query) ||
            (p.barcode?.contains(query) ?? false))
        .toList();
  }

  Future<SaleResult> createSale({
    required List<MapEntry<Product, double>> items,
    required double montoRecibido,
  }) async {
    final uri = await _uri('/sales');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'medioPago': 'EFECTIVO',
            'montoRecibido': montoRecibido,
            'items': items
                .map((e) => {'productId': e.key.id, 'cantidad': e.value})
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    return SaleResult.fromJson(_decodeObject(response));
  }

  Future<Map<String, dynamic>> fetchSalesToday() async {
    final uri = await _uri('/reports/sales-today');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    return _decodeObject(response);
  }

  Future<Map<String, String>> fetchSettings() async {
    final uri = await _uri('/settings');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return map.map((key, value) => MapEntry(key, value.toString()));
  }
}
