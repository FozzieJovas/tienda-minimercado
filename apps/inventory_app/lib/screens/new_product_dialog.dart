import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import 'barcode_scanner_screen.dart';

Future<Product?> showNewProductDialog(
  BuildContext context, {
  required ApiClient api,
  required String barcode,
}) {
  return showDialog<Product>(
    context: context,
    builder: (context) => _NewProductDialog(api: api, barcode: barcode),
  );
}

/// Variante usada tras el escaneo de facturas con IA: no hay código de barras
/// todavía, pero sí un nombre/costo sugeridos a partir de lo extraído.
Future<Product?> showNewProductDialogWithDefaults(
  BuildContext context, {
  required ApiClient api,
  String? nombreSugerido,
  double? costoSugerido,
}) {
  return showDialog<Product>(
    context: context,
    builder: (context) => _NewProductDialog(
      api: api,
      barcode: null,
      nombreSugerido: nombreSugerido,
      costoSugerido: costoSugerido,
    ),
  );
}

class _NewProductDialog extends StatefulWidget {
  final ApiClient api;
  final String? barcode;
  final String? nombreSugerido;
  final double? costoSugerido;

  const _NewProductDialog({
    required this.api,
    required this.barcode,
    this.nombreSugerido,
    this.costoSugerido,
  });

  @override
  State<_NewProductDialog> createState() => _NewProductDialogState();
}

class _NewProductDialogState extends State<_NewProductDialog> {
  late final _nombreController = TextEditingController(text: widget.nombreSugerido ?? '');
  late final _barcodeController = TextEditingController(text: widget.barcode ?? '');
  late final _costoController = TextEditingController(
    text: widget.costoSugerido != null ? widget.costoSugerido!.toStringAsFixed(0) : '',
  );
  bool _submitting = false;
  String? _error;

  Future<void> _crear() async {
    final nombre = _nombreController.text.trim();
    final costo = double.tryParse(_costoController.text);
    if (nombre.isEmpty || costo == null) {
      setState(() => _error = 'Completa el nombre y el costo');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final barcode = _barcodeController.text.trim();
      final product = await widget.api.createProduct(
        nombre: nombre,
        barcode: barcode.isEmpty ? null : barcode,
        costoActual: costo,
      );
      if (mounted) Navigator.of(context).pop(product);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo crear el producto';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Producto nuevo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nombreController,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          BarcodeField(controller: _barcodeController),
          TextField(
            controller: _costoController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Costo de compra'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _crear,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
