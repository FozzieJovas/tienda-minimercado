class SaleItemResult {
  final String productId;
  final String nombreProducto;
  final double cantidad;
  final double precioUnitario;
  final double subtotal;

  SaleItemResult({
    required this.productId,
    required this.nombreProducto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory SaleItemResult.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return SaleItemResult(
      productId: json['productId'] as String,
      nombreProducto: product?['nombre'] as String? ?? '',
      cantidad: (json['cantidad'] as num).toDouble(),
      precioUnitario: (json['precioUnitario'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
    );
  }
}

class SaleResult {
  final String id;
  final int numeroTicket;
  final double subtotal;
  final double descuento;
  final double total;
  final String medioPago;
  final double? montoRecibido;
  final double? cambio;
  final DateTime fecha;
  final List<SaleItemResult> items;

  SaleResult({
    required this.id,
    required this.numeroTicket,
    required this.subtotal,
    required this.descuento,
    required this.total,
    required this.medioPago,
    required this.montoRecibido,
    required this.cambio,
    required this.fecha,
    required this.items,
  });

  factory SaleResult.fromJson(Map<String, dynamic> json) {
    return SaleResult(
      id: json['id'] as String,
      numeroTicket: json['numeroTicket'] as int,
      subtotal: (json['subtotal'] as num).toDouble(),
      descuento: (json['descuento'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      medioPago: json['medioPago'] as String,
      montoRecibido: (json['montoRecibido'] as num?)?.toDouble(),
      cambio: (json['cambio'] as num?)?.toDouble(),
      fecha: DateTime.parse(json['fecha'] as String),
      items: (json['items'] as List<dynamic>)
          .map((e) => SaleItemResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
