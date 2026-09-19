class Product {
  final String id;
  final String nombre;
  final String? barcode;
  final double precioVenta;
  final double stockActual;

  Product({
    required this.id,
    required this.nombre,
    required this.barcode,
    required this.precioVenta,
    required this.stockActual,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      barcode: json['barcode'] as String?,
      precioVenta: (json['precioVenta'] as num).toDouble(),
      stockActual: (json['stockActual'] as num).toDouble(),
    );
  }
}
