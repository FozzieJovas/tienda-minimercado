import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/app_user.dart';
import '../models/product.dart';
import '../models/scan_result.dart';
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

  Future<AppUser> login(String usuario, String password) async {
    final uri = await _uri('/auth/login');
    final response = await http
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'usuario': usuario, 'password': password}))
        .timeout(const Duration(seconds: 10));
    return AppUser.fromJson(_decodeObject(response));
  }

  Future<Product?> findByBarcode(String barcode) async {
    final uri = await _uri('/products/by-barcode/$barcode');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 404) return null;
    return Product.fromJson(_decodeObject(response));
  }

  Future<List<Product>> searchProducts(String query) async {
    final uri = await _uri('/products?activo=true');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode >= 400) throw ApiException('No se pudo cargar el catálogo');
    final list = jsonDecode(response.body) as List<dynamic>;
    final products = list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products
        .where((p) => p.nombre.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false))
        .toList();
  }

  Future<Product> createProduct({
    required String nombre,
    String? barcode,
    required double costoActual,
    double stockActual = 0,
    double stockMinimo = 0,
  }) async {
    final uri = await _uri('/products');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'nombre': nombre,
            if (barcode != null) 'barcode': barcode,
            'costoActual': costoActual,
            'stockActual': stockActual,
            'stockMinimo': stockMinimo,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return Product.fromJson(_decodeObject(response));
  }

  Future<void> registrarCompra({
    required List<({String productId, double cantidad, double costoUnitario})> items,
    String? numeroFactura,
    String? creadoPorId,
    String? scanId,
  }) async {
    final uri = await _uri('/purchases');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            if (numeroFactura != null) 'numeroFactura': numeroFactura,
            if (creadoPorId != null) 'creadoPorId': creadoPorId,
            if (scanId != null) 'scanId': scanId,
            'items': items
                .map((i) => {
                      'productId': i.productId,
                      'cantidad': i.cantidad,
                      'costoUnitario': i.costoUnitario,
                    })
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    _decodeObject(response);
  }

  Future<ScanResult> scanInvoice(List<File> fotos) async {
    final uri = await _uri('/purchases/scan');
    final request = http.MultipartRequest('POST', uri);
    for (final foto in fotos) {
      request.files.add(await http.MultipartFile.fromPath('fotos', foto.path));
    }
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    return ScanResult.fromJson(_decodeObject(response));
  }

  Future<Product> ajustarStock({
    required String productId,
    required double cantidadDelta,
    required String tipo,
    String? motivo,
  }) async {
    final uri = await _uri('/products/$productId/stock-adjustment');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'cantidadDelta': cantidadDelta,
            'tipo': tipo,
            if (motivo != null) 'motivo': motivo,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return Product.fromJson(_decodeObject(response));
  }
}
