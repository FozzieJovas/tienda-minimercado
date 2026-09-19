import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/cart.dart';
import '../models/sale.dart';
import '../services/api_client.dart';

final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

Future<SaleResult?> showCheckoutDialog(
  BuildContext context, {
  required Cart cart,
  required ApiClient api,
}) {
  return showDialog<SaleResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CheckoutDialog(cart: cart, api: api),
  );
}

class _CheckoutDialog extends StatefulWidget {
  final Cart cart;
  final ApiClient api;

  const _CheckoutDialog({required this.cart, required this.api});

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  final _montoController = TextEditingController();
  bool _submitting = false;
  String? _error;

  double get _total => widget.cart.total;

  double get _montoRecibido => double.tryParse(_montoController.text) ?? 0;

  double get _cambio => _montoRecibido - _total;

  Future<void> _confirmar() async {
    if (_montoRecibido < _total) {
      setState(() => _error = 'El monto recibido es menor al total');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final sale = await widget.api.createSale(
        items: widget.cart.toApiItems(),
        montoRecibido: _montoRecibido,
      );
      if (mounted) Navigator.of(context).pop(sale);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo conectar con el servidor';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cobrar (efectivo)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total: ${_currency.format(_total)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _montoController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Monto recibido'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text('Cambio: ${_currency.format(_cambio < 0 ? 0 : _cambio)}'),
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
          onPressed: _submitting ? null : _confirmar,
          child: _submitting
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirmar venta'),
        ),
      ],
    );
  }
}
