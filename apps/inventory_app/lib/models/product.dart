class Product {
  final String id;
  final String nombre;
  final String? barcode;
  final double costoActual;
  final double precioVenta;
  final double stockActual;
  final double? margenOverride;
  final bool favorito;

  Product({
    required this.id,
    required this.nombre,
    required this.barcode,
    required this.costoActual,
    required this.precioVenta,
    required this.stockActual,
    this.margenOverride,
    this.favorito = false,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      barcode: json['barcode'] as String?,
      costoActual: (json['costoActual'] as num).toDouble(),
      precioVenta: (json['precioVenta'] as num).toDouble(),
      stockActual: (json['stockActual'] as num).toDouble(),
      margenOverride: (json['margenOverride'] as num?)?.toDouble(),
      favorito: json['favorito'] as bool? ?? false,
    );
  }
}
