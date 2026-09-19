import 'package:flutter/foundation.dart';
import 'product.dart';

class CartLine {
  final Product product;
  double cantidad;

  CartLine({required this.product, required this.cantidad});

  double get subtotal => product.precioVenta * cantidad;
}

class Cart extends ChangeNotifier {
  final Map<String, CartLine> _lines = {};

  List<CartLine> get lines => _lines.values.toList(growable: false);

  double get total =>
      _lines.values.fold(0, (sum, line) => sum + line.subtotal);

  bool get isEmpty => _lines.isEmpty;

  void addProduct(Product product) {
    final existing = _lines[product.id];
    if (existing != null) {
      existing.cantidad += 1;
    } else {
      _lines[product.id] = CartLine(product: product, cantidad: 1);
    }
    notifyListeners();
  }

  void setCantidad(String productId, double cantidad) {
    if (cantidad <= 0) {
      _lines.remove(productId);
    } else {
      _lines[productId]?.cantidad = cantidad;
    }
    notifyListeners();
  }

  void removeLine(String productId) {
    _lines.remove(productId);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  List<MapEntry<Product, double>> toApiItems() =>
      _lines.values.map((l) => MapEntry(l.product, l.cantidad)).toList();
}
