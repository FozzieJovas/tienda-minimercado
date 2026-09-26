import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import 'barcode_scanner_screen.dart';

Future<Product?> showSelectProductDialog(BuildContext context, {required ApiClient api}) {
  return showDialog<Product>(
    context: context,
    builder: (context) => _SelectProductDialog(api: api),
  );
}

class _SelectProductDialog extends StatefulWidget {
  final ApiClient api;

  const _SelectProductDialog({required this.api});

  @override
  State<_SelectProductDialog> createState() => _SelectProductDialogState();
}

class _SelectProductDialogState extends State<_SelectProductDialog> {
  final _controller = TextEditingController();
  List<Product> _results = [];
  bool _loading = false;

  Future<void> _buscar(String query) async {
    setState(() => _loading = true);
    try {
      _results = await widget.api.searchProducts(query);
    } catch (_) {
      _results = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  Future<void> _escanear() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;
    try {
      final product = await widget.api.findByBarcode(code);
      if (!mounted) return;
      if (product != null) {
        Navigator.of(context).pop(product);
        return;
      }
    } catch (_) {
      // sin conexión: se deja el código como texto de búsqueda
    }
    _controller.text = code;
    _buscar(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir producto'),
      content: SizedBox(
        width: 320,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Buscar',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Escanear código de barras',
                  onPressed: _escanear,
                ),
              ),
              onChanged: _buscar,
            ),
            const SizedBox(height: 8),
            if (_loading) const CircularProgressIndicator(),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final product = _results[index];
                  return ListTile(
                    title: Text(product.nombre),
                    onTap: () => Navigator.of(context).pop(product),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    );
  }
}
