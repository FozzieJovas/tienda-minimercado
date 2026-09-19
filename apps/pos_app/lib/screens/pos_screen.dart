import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/cart.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import '../services/session_service.dart';
import '../services/settings_service.dart';
import '../services/printer_service.dart';
import 'cash_session_screen.dart';
import 'checkout_dialog.dart';
import 'sales_today_screen.dart';
import 'settings_screen.dart';

final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

class PosScreen extends StatefulWidget {
  final AppUser user;
  final String sessionId;
  final VoidCallback onLoggedOut;
  final VoidCallback onSessionClosed;

  const PosScreen({
    super.key,
    required this.user,
    required this.sessionId,
    required this.onLoggedOut,
    required this.onSessionClosed,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _api = ApiClient(SettingsService());
  final _printerService = PrinterService();
  final _settings = SettingsService();
  final _sessionService = SessionService();
  final _searchController = TextEditingController();

  List<Product> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _api.fetchProducts(search: _searchController.text);
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo conectar con el servidor. Revisa la configuración.';
        _loading = false;
      });
    }
  }

  Future<void> _cobrar(Cart cart) async {
    final sale = await showCheckoutDialog(
      context,
      cart: cart,
      api: _api,
      usuarioId: widget.user.id,
      sesionId: widget.sessionId,
    );
    if (sale == null) return;

    cart.clear();
    await _loadProducts();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Venta #${sale.numeroTicket} registrada')),
    );

    final printerMac = await _settings.getPrinterMac();
    if (printerMac == null) return;
    try {
      final settingsMap = await _api.fetchSettings();
      final bytes = await _printerService.buildTicketBytes(
        sale: sale,
        nombreTienda: settingsMap['nombre_tienda'] ?? 'Mi Tienda',
        piePagina: settingsMap['pie_ticket'],
      );
      await _printerService.connect(printerMac);
      await _printerService.printTicket(bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo imprimir el ticket')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Cart(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Punto de venta — ${widget.user.nombre}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.point_of_sale),
              tooltip: 'Turno de caja',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CashSessionScreen(
                      user: widget.user,
                      sessionId: widget.sessionId,
                      onClosed: () {
                        Navigator.of(context).pop();
                        widget.onSessionClosed();
                      },
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Ventas de hoy',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SalesTodayScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configuración',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                _loadProducts();
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                await _sessionService.logout();
                widget.onLoggedOut();
              },
            ),
          ],
        ),
        body: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Buscar por nombre o código de barras',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _loadProducts(),
                    ),
                  ),
                  Expanded(child: _buildProductList()),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 2,
              child: _CartPanel(onCobrar: _cobrar),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadProducts, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(child: Text('Sin productos'));
    }
    return Builder(builder: (context) {
      final cart = context.watch<Cart>();
      return ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return ListTile(
            title: Text(product.nombre),
            subtitle: Text('Stock: ${product.stockActual.toStringAsFixed(0)}'),
            trailing: Text(_currency.format(product.precioVenta)),
            onTap: () => cart.addProduct(product),
          );
        },
      );
    });
  }
}

class _CartPanel extends StatelessWidget {
  final Future<void> Function(Cart cart) onCobrar;

  const _CartPanel({required this.onCobrar});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    return Column(
      children: [
        Expanded(
          child: cart.isEmpty
              ? const Center(child: Text('Carrito vacío'))
              : ListView(
                  children: cart.lines
                      .map((line) => ListTile(
                            title: Text(line.product.nombre),
                            subtitle: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => cart.setCantidad(
                                      line.product.id, line.cantidad - 1),
                                ),
                                Text(line.cantidad.toStringAsFixed(0)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => cart.setCantidad(
                                      line.product.id, line.cantidad + 1),
                                ),
                              ],
                            ),
                            trailing: Text(_currency.format(line.subtotal)),
                          ))
                      .toList(),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(_currency.format(cart.total),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: cart.isEmpty ? null : () => onCobrar(cart),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: const Text('Cobrar', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
