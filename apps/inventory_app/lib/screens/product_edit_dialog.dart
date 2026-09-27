import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import 'barcode_scanner_screen.dart';
import 'presentacion_selector.dart';

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
  late var _presentacion = PresentacionSeleccion(
    activo: widget.product.esPresentacion,
    baseId: widget.product.presentacionDeId,
    factor: widget.product.factor,
  );
  late List<ProductAlias> _aliases = widget.product.aliases;
  bool _submitting = false;
  String? _error;

  Future<void> _quitarAlias(ProductAlias alias) async {
    try {
      final actualizado = await widget.api.deleteAlias(widget.product.id, alias.id);
      setState(() => _aliases = actualizado.aliases);
    } catch (_) {
      setState(() => _error = 'No se pudo quitar el nombre de factura');
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final costo = double.tryParse(_costoController.text);
    if (nombre.isEmpty || costo == null) {
      setState(() => _error = 'Completa el nombre y el costo');
      return;
    }
    if (_presentacion.error != null) {
      setState(() => _error = _presentacion.error);
      return;
    }
    // Solo se envía el costo si se cambió: así, al vincular una caja a su unidad,
    // el servidor toma el costo de la unidad × factor en vez de uno viejo.
    final costoCambio = _costoController.text != widget.product.costoActual.toStringAsFixed(0);
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
        if (costoCambio) 'costoActual': costo,
        'margenOverride': margenOverride,
        'favorito': _favorito,
        'presentacionDeId': _presentacion.activo ? _presentacion.baseId : null,
        if (_presentacion.activo) 'factor': _presentacion.factor,
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
              decoration: const InputDecoration(labelText: 'Nombre de venta'),
            ),
            if (_aliases.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Nombres en facturas (para reconocerlo al escanear):',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final alias in _aliases)
                    InputChip(
                      label: Text(alias.original, style: const TextStyle(fontSize: 12)),
                      onDeleted: () => _quitarAlias(alias),
                      deleteButtonTooltipMessage: 'Quitar',
                    ),
                ],
              ),
            ],
            BarcodeField(controller: _barcodeController),
            TextField(
              controller: _costoController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _presentacion.activo ? 'Costo del paquete' : 'Costo de compra actual',
                helperText: 'Al cambiarlo se actualizan también sus cajas/unidades',
              ),
            ),
            PresentacionSelector(
              api: widget.api,
              excluirId: widget.product.id,
              baseIdInicial: widget.product.presentacionDeId,
              baseNombreInicial: widget.product.presentacionDeNombre,
              factorInicial: widget.product.factor,
              onChanged: (s) => setState(() => _presentacion = s),
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
