import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';
import 'barcode_scanner_screen.dart';
import 'new_product_dialog.dart';
import 'quantity_cost_dialog.dart';
import 'select_product_dialog.dart';

final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

class ReceptionItem {
  final Product product;
  final double cantidad;
  final double costoUnitario;

  ReceptionItem({required this.product, required this.cantidad, required this.costoUnitario});
}

class ReceptionScreen extends StatefulWidget {
  final AppUser user;

  const ReceptionScreen({super.key, required this.user});

  @override
  State<ReceptionScreen> createState() => _ReceptionScreenState();
}

class _ReceptionScreenState extends State<ReceptionScreen> {
  final _api = ApiClient(SettingsService());
  final _numeroFacturaController = TextEditingController();
  final List<ReceptionItem> _items = [];
  bool _submitting = false;

  double get _total => _items.fold(0, (sum, i) => sum + i.cantidad * i.costoUnitario);

  Future<void> _escanear() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;

    Product? product;
    try {
      product = await _api.findByBarcode(code);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor')));
      }
      return;
    }

    if (!mounted) return;
    if (product == null) {
      product = await showNewProductDialog(context, api: _api, barcode: code);
      if (product == null) return;
    }

    if (!mounted) return;
    await _agregarItem(product);
  }

  /// Para productos sin código de barras (o cuando no se tiene a mano el lector):
  /// buscar por nombre en el catálogo en vez de escanear.
  Future<void> _buscarManual() async {
    final product = await showSelectProductDialog(context, api: _api);
    if (product == null || !mounted) return;
    await _agregarItem(product);
  }

  Future<void> _agregarItem(Product product) async {
    final result = await showQuantityCostDialog(
      context,
      productName: product.nombre,
      costoSugerido: product.costoActual,
    );
    if (result == null) return;

    setState(() {
      _items.add(ReceptionItem(product: product, cantidad: result.cantidad, costoUnitario: result.costoUnitario));
    });
  }

  Future<void> _guardarCompra() async {
    if (_items.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await _api.registrarCompra(
        items: _items
            .map((i) => (productId: i.product.id, cantidad: i.cantidad, costoUnitario: i.costoUnitario))
            .toList(),
        numeroFactura: _numeroFacturaController.text.trim().isEmpty ? null : _numeroFacturaController.text.trim(),
        creadoPorId: widget.user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compra registrada')));
      setState(() {
        _items.clear();
        _numeroFacturaController.clear();
      });
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
      appBar: AppBar(title: const Text('Recepción de mercancía')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _numeroFacturaController,
              decoration: const InputDecoration(labelText: 'N.º de factura del proveedor (opcional)'),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('Escanea un producto para empezar'))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        title: Text(item.product.nombre),
                        subtitle: Text('${item.cantidad.toStringAsFixed(0)} x ${_currency.format(item.costoUnitario)}'),
                        trailing: Text(_currency.format(item.cantidad * item.costoUnitario)),
                      );
                    },
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _escanear,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Escanear'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _buscarManual,
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar por nombre'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _items.isEmpty || _submitting ? null : _guardarCompra,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Guardar compra'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
