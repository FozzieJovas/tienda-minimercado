import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../services/api_client.dart';

Future<Product?> showProductEditDialog(
  BuildContext context, {
  required ApiClient api,
  required Product product,
}) {
  return showDialog<Product>(
    context: context,
    builder: (context) => _ProductEditDialog(api: api, product: product),
  );
}

class _ProductEditDialog extends StatefulWidget {
  final ApiClient api;
  final Product product;

  const _ProductEditDialog({required this.api, required this.product});

  @override
  State<_ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<_ProductEditDialog> {
  late final _nombreController = TextEditingController(text: widget.product.nombre);
  late final _barcodeController = TextEditingController(text: widget.product.barcode ?? '');
  late final _costoController =
      TextEditingController(text: widget.product.costoActual.toStringAsFixed(0));
  late final _margenController = TextEditingController(
    text: widget.product.margenOverride != null
        ? (widget.product.margenOverride! * 100).toStringAsFixed(0)
        : '',
  );
  late bool _usarOverride = widget.product.margenOverride != null;
  late bool _favorito = widget.product.favorito;
  bool _submitting = false;
  String? _error;

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final costo = double.tryParse(_costoController.text);
    if (nombre.isEmpty || costo == null) {
      setState(() => _error = 'Completa el nombre y el costo');
      return;
    }
    double? margenOverride;
    if (_usarOverride) {
      final pct = double.tryParse(_margenController.text);
      if (pct == null) {
        setState(() => _error = 'Indica el margen en % o desactiva el override');
        return;
      }
      margenOverride = pct / 100;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final barcode = _barcodeController.text.trim();
      final product = await widget.api.updateProduct(widget.product.id, {
        'nombre': nombre,
        'barcode': barcode.isEmpty ? null : barcode,
        'costoActual': costo,
        'margenOverride': margenOverride,
        'favorito': _favorito,
      });
      if (mounted) Navigator.of(context).pop(product);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo guardar el producto';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar producto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: _barcodeController,
              decoration: const InputDecoration(labelText: 'Código de barras (opcional)'),
            ),
            TextField(
              controller: _costoController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Costo de compra actual'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Margen propio para este producto'),
              subtitle: const Text('Si está apagado, usa el margen de categoría o el general'),
              value: _usarOverride,
              onChanged: (v) => setState(() => _usarOverride = v),
            ),
            if (_usarOverride)
              TextField(
                controller: _margenController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Margen (%)', suffixText: '%'),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Favorito (visible en el POS)'),
              value: _favorito,
              onChanged: (v) => setState(() => _favorito = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _guardar,
          child: _submitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
