import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../services/api_client.dart';

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

class _NewProductDialog extends StatefulWidget {
  final ApiClient api;
  final String barcode;

  const _NewProductDialog({required this.api, required this.barcode});

  @override
  State<_NewProductDialog> createState() => _NewProductDialogState();
}

class _NewProductDialogState extends State<_NewProductDialog> {
  final _nombreController = TextEditingController();
  final _costoController = TextEditingController();
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
      final product = await widget.api.createProduct(
        nombre: nombre,
        barcode: widget.barcode,
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
          Text('Código: ${widget.barcode}'),
          TextField(
            controller: _nombreController,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
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
