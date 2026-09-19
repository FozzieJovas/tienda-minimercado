class ScanItem {
  final String descripcionCruda;
  double cantidad;
  double costoUnitario;
  String? productId;
  String? nombreProductoSugerido;
  double? precioVentaSugerido;
  final String? confianzaMatch;

  ScanItem({
    required this.descripcionCruda,
    required this.cantidad,
    required this.costoUnitario,
    required this.productId,
    required this.nombreProductoSugerido,
    required this.precioVentaSugerido,
    required this.confianzaMatch,
  });

  factory ScanItem.fromJson(Map<String, dynamic> json) => ScanItem(
        descripcionCruda: json['descripcionCruda'] as String,
        cantidad: (json['cantidad'] as num).toDouble(),
        costoUnitario: (json['costoUnitario'] as num).toDouble(),
        productId: json['productId'] as String?,
        nombreProductoSugerido: json['nombreProductoSugerido'] as String?,
        precioVentaSugerido: (json['precioVentaSugerido'] as num?)?.toDouble(),
        confianzaMatch: json['confianzaMatch'] as String?,
      );
}

class ScanResult {
  final String scanId;
  final String? proveedorNombre;
  final String? numeroFactura;
  final String? fecha;
  final String confianzaGeneral;
  final List<ScanItem> items;

  ScanResult({
    required this.scanId,
    required this.proveedorNombre,
    required this.numeroFactura,
    required this.fecha,
    required this.confianzaGeneral,
    required this.items,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        scanId: json['scanId'] as String,
        proveedorNombre: json['proveedorNombre'] as String?,
        numeroFactura: json['numeroFactura'] as String?,
        fecha: json['fecha'] as String?,
        confianzaGeneral: json['confianzaGeneral'] as String,
        items: (json['items'] as List<dynamic>)
            .map((e) => ScanItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
