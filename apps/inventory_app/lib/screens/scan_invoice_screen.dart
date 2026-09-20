import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../models/scan_result.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';
import 'new_product_dialog.dart';
import 'select_product_dialog.dart';

final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

const _confianzaColor = {
  'alta': Colors.green,
  'media': Colors.orange,
  'baja': Colors.red,
};

class ScanInvoiceScreen extends StatefulWidget {
  final AppUser user;

  const ScanInvoiceScreen({super.key, required this.user});

  @override
  State<ScanInvoiceScreen> createState() => _ScanInvoiceScreenState();
}

class _ScanInvoiceScreenState extends State<ScanInvoiceScreen> {
  final _api = ApiClient(SettingsService());
  final _picker = ImagePicker();
  final List<File> _fotos = [];
  ScanResult? _result;
  bool _scanning = false;
  bool _submitting = false;
  String? _error;

  double get _total => (_result?.items ?? []).fold(0, (sum, i) => sum + i.cantidad * i.costoUnitario);

  bool get _todoResuelto =>
      (_result?.items ?? []).isNotEmpty && _result!.items.every((i) => i.productId != null);

  Future<void> _tomarFoto() async {
    final foto = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (foto == null) return;
    setState(() => _fotos.add(File(foto.path)));
  }

  Future<void> _escanear() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final result = await _api.scanInvoice(_fotos);
      setState(() => _result = result);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _cambiarProducto(ScanItem item) async {
    final product = await showSelectProductDialog(context, api: _api);
    if (product == null) return;
    setState(() {
      item.productId = product.id;
      item.nombreProductoSugerido = product.nombre;
    });
  }

  Future<void> _crearProducto(ScanItem item) async {
    final product = await showNewProductDialogWithDefaults(
      context,
      api: _api,
      nombreSugerido: item.descripcionCruda,
      costoSugerido: item.costoUnitario,
    );
    if (product == null) return;
    setState(() {
      item.productId = product.id;
      item.nombreProductoSugerido = product.nombre;
    });
  }

  void _eliminarItem(ScanItem item) {
    setState(() => _result!.items.remove(item));
  }

  Future<void> _confirmarCompra() async {
    if (_result == null || !_todoResuelto) return;
    setState(() => _submitting = true);
    try {
      await _api.registrarCompra(
        items: _result!.items
            .map((i) => (productId: i.productId!, cantidad: i.cantidad, costoUnitario: i.costoUnitario))
            .toList(),
        numeroFactura: _result!.numeroFactura,
        creadoPorId: widget.user.id,
        scanId: _result!.scanId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compra registrada')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo registrar la compra')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear factura (IA)')),
      body: _result == null ? _buildCaptura() : _buildRevision(),
    );
  }

  Widget _buildCaptura() {
    return Column(
      children: [
        Expanded(
          child: _fotos.isEmpty
              ? const Center(child: Text('Toma una o varias fotos de la factura'))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                  itemCount: _fotos.length,
                  itemBuilder: (context, index) => Stack(
                    children: [
                      Positioned.fill(child: Image.file(_fotos[index], fit: BoxFit.cover)),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => setState(() => _fotos.removeAt(index)),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _tomarFoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tomar foto'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _fotos.isEmpty || _scanning ? null : _escanear,
                  child: _scanning
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Escanear con IA'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRevision() {
    final result = _result!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (result.proveedorNombre != null) Text('Proveedor: ${result.proveedorNombre}'),
              if (result.numeroFactura != null) Text('Factura: ${result.numeroFactura}'),
              Text('Confianza general de la IA: ${result.confianzaGeneral}'),
              const SizedBox(height: 8),
              if (result.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 40, color: Colors.orange),
                      const SizedBox(height: 8),
                      const Text(
                        'La IA no logró leer ningún ítem en esta foto. Intenta con más luz, '
                        'más cerca del texto, o encuadrando solo la factura.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _result = null;
                          _fotos.clear();
                        }),
                        child: const Text('Volver a tomar fotos'),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  'Revisa cada ítem antes de confirmar. La confianza indica qué tan segura está la IA del emparejamiento con tu catálogo.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 24),
                for (final item in result.items) _buildItemCard(item),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_currency.format(_total), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !_todoResuelto || _submitting ? null : _confirmarCompra,
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_todoResuelto ? 'Confirmar compra' : 'Resuelve todos los productos primero'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(ScanItem item) {
    final cantidadController = TextEditingController(text: item.cantidad.toStringAsFixed(0));
    final costoController = TextEditingController(text: item.costoUnitario.toStringAsFixed(0));
    final color = _confianzaColor[item.confianzaMatch] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.descripcionCruda, style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _eliminarItem(item),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 6),
                Text(
                  item.productId != null
                      ? 'Coincide con: ${item.nombreProductoSugerido}'
                      : 'Producto nuevo (sin coincidencia)',
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => _cambiarProducto(item),
                  child: const Text('Elegir otro'),
                ),
                if (item.productId == null)
                  TextButton(
                    onPressed: () => _crearProducto(item),
                    child: const Text('Crear producto'),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cantidadController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    onChanged: (v) => setState(() => item.cantidad = double.tryParse(v) ?? item.cantidad),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: costoController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Costo unitario'),
                    onChanged: (v) => setState(() => item.costoUnitario = double.tryParse(v) ?? item.costoUnitario),
                  ),
                ),
              ],
            ),
            Text('Subtotal: ${_currency.format(item.cantidad * item.costoUnitario)}'),
          ],
        ),
      ),
    );
  }
}
