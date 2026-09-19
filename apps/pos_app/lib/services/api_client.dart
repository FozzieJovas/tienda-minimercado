import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_user.dart';
import '../models/cash_session.dart';
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
    required String medioPago,
    double? montoRecibido,
    double? montoEfectivo,
    String? usuarioId,
    String? sesionId,
  }) async {
    final uri = await _uri('/sales');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'medioPago': medioPago,
            if (montoRecibido != null) 'montoRecibido': montoRecibido,
            if (montoEfectivo != null) 'montoEfectivo': montoEfectivo,
            if (usuarioId != null) 'usuarioId': usuarioId,
            if (sesionId != null) 'sesionId': sesionId,
            'items': items
                .map((e) => {'productId': e.key.id, 'cantidad': e.value})
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    return SaleResult.fromJson(_decodeObject(response));
  }

  Future<AppUser> login(String usuario, String password) async {
    final uri = await _uri('/auth/login');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'usuario': usuario, 'password': password}),
        )
        .timeout(const Duration(seconds: 10));
    return AppUser.fromJson(_decodeObject(response));
  }

  Future<CashSession?> fetchCurrentSession() async {
    final uri = await _uri('/cash-sessions/current');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 404) return null;
    return CashSession.fromJson(_decodeObject(response));
  }

  Future<CashSession> openSession({required double fondoInicial, String? usuarioAperturaId}) async {
    final uri = await _uri('/cash-sessions');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fondoInicial': fondoInicial,
            if (usuarioAperturaId != null) 'usuarioAperturaId': usuarioAperturaId,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return CashSession.fromJson(_decodeObject(response));
  }

  Future<void> addCashMovement({
    required String sessionId,
    required String tipo,
    required double monto,
    String? motivo,
  }) async {
    final uri = await _uri('/cash-sessions/$sessionId/movements');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'tipo': tipo, 'monto': monto, if (motivo != null) 'motivo': motivo}),
        )
        .timeout(const Duration(seconds: 10));
    _decodeObject(response);
  }

  Future<CashSessionClosed> closeSession({
    required String sessionId,
    required double efectivoContado,
    String? usuarioCierreId,
  }) async {
    final uri = await _uri('/cash-sessions/$sessionId/cerrar');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'efectivoContado': efectivoContado,
            if (usuarioCierreId != null) 'usuarioCierreId': usuarioCierreId,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return CashSessionClosed.fromJson(_decodeObject(response));
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
