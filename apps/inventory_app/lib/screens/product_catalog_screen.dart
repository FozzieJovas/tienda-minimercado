import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';
import 'new_product_dialog.dart';
import 'product_edit_dialog.dart';

final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  final _api = ApiClient(SettingsService());
  final _searchController = TextEditingController();
  List<Product> _products = [];
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _buscar('');
    _searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () => _buscar(_searchController.text));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _buscar(String query) async {
    setState(() => _loading = true);
    try {
      final products = await _api.searchProducts(query);
      if (mounted) setState(() => _products = products);
    } catch (_) {
      // se deja la última lista visible
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorito(Product product) async {
    try {
      await _api.updateProduct(product.id, {'favorito': !product.favorito});
      _buscar(_searchController.text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se pudo actualizar el favorito')));
      }
    }
  }

  Future<void> _editar(Product product) async {
    final updated = await showProductEditDialog(context, api: _api, product: product);
    if (updated != null) _buscar(_searchController.text);
  }

  Future<void> _crear() async {
    final created = await showNewProductDialogWithDefaults(context, api: _api);
    if (created != null) _buscar(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de productos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre o código de barras',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _products.isEmpty && !_loading
                ? const Center(child: Text('Sin productos'))
                : ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return ListTile(
                        leading: IconButton(
                          icon: Icon(
                            product.favorito ? Icons.star : Icons.star_border,
                            color: product.favorito ? Colors.amber : null,
                          ),
                          tooltip: 'Marcar como favorito (visible en el POS)',
                          onPressed: () => _toggleFavorito(product),
                        ),
                        title: Text(product.nombre),
                        subtitle: Text(
                          'Costo: ${_currency.format(product.costoActual)}  ·  '
                          'Venta: ${_currency.format(product.precioVenta)}'
                          '${product.margenOverride != null ? '  ·  margen propio: ${(product.margenOverride! * 100).toStringAsFixed(0)}%' : ''}',
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editar(product),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _crear,
        tooltip: 'Nuevo producto',
        child: const Icon(Icons.add),
      ),
    );
  }
}
