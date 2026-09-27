class ProductAlias {
  final String id;
  final String original;

  ProductAlias({required this.id, required this.original});

  factory ProductAlias.fromJson(Map<String, dynamic> json) =>
      ProductAlias(id: json['id'] as String, original: json['original'] as String);
}

class Product {
  final String id;
  final String nombre;
  final String? barcode;
  final double costoActual;
  final double precioVenta;
  final double stockActual;
  final double? margenOverride;
  final bool favorito;
  final String? presentacionDeId;
  final String? presentacionDeNombre;
  final double factor;
  final List<ProductAlias> aliases;

  Product({
    required this.id,
    required this.nombre,
    required this.barcode,
    required this.costoActual,
    required this.precioVenta,
    required this.stockActual,
    this.margenOverride,
    this.favorito = false,
    this.presentacionDeId,
    this.presentacionDeNombre,
    this.factor = 1,
    this.aliases = const [],
  });

  bool get esPresentacion => presentacionDeId != null;

  factory Product.fromJson(Map<String, dynamic> json) {
    final base = json['presentacionDe'] as Map<String, dynamic>?;
    return Product(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      barcode: json['barcode'] as String?,
      costoActual: (json['costoActual'] as num).toDouble(),
      precioVenta: (json['precioVenta'] as num).toDouble(),
      stockActual: (json['stockActual'] as num).toDouble(),
      margenOverride: (json['margenOverride'] as num?)?.toDouble(),
      favorito: json['favorito'] as bool? ?? false,
      presentacionDeId: json['presentacionDeId'] as String?,
      presentacionDeNombre: base?['nombre'] as String?,
      factor: (json['factor'] as num?)?.toDouble() ?? 1,
      aliases: ((json['aliases'] as List<dynamic>?) ?? [])
          .map((e) => ProductAlias.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
