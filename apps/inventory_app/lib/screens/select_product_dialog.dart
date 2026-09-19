import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_client.dart';

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
              decoration: const InputDecoration(labelText: 'Buscar'),
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
