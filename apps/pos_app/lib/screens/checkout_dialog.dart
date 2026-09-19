import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/cart.dart';
import '../models/sale.dart';
import '../services/api_client.dart';

final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

const _medioPagoLabels = {
  'EFECTIVO': 'Efectivo',
  'TARJETA': 'Tarjeta',
  'TRANSFERENCIA': 'Transferencia',
  'MIXTO': 'Mixto',
};

Future<SaleResult?> showCheckoutDialog(
  BuildContext context, {
  required Cart cart,
  required ApiClient api,
  String? usuarioId,
  String? sesionId,
}) {
  return showDialog<SaleResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CheckoutDialog(cart: cart, api: api, usuarioId: usuarioId, sesionId: sesionId),
  );
}

class _CheckoutDialog extends StatefulWidget {
  final Cart cart;
  final ApiClient api;
  final String? usuarioId;
  final String? sesionId;

  const _CheckoutDialog({required this.cart, required this.api, this.usuarioId, this.sesionId});

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  final _montoController = TextEditingController();
  String _medioPago = 'EFECTIVO';
  bool _submitting = false;
  String? _error;

  double get _total => widget.cart.total;

  double get _montoIngresado => double.tryParse(_montoController.text) ?? 0;

  double get _cambio => _montoIngresado - _total;

  Future<void> _confirmar() async {
    if (_medioPago == 'EFECTIVO' && _montoIngresado < _total) {
      setState(() => _error = 'El monto recibido es menor al total');
      return;
    }
    if (_medioPago == 'MIXTO' && (_montoIngresado <= 0 || _montoIngresado > _total)) {
      setState(() => _error = 'Indica cuánto de la venta se pagó en efectivo');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final sale = await widget.api.createSale(
        items: widget.cart.toApiItems(),
        medioPago: _medioPago,
        montoRecibido: _medioPago == 'EFECTIVO' ? _montoIngresado : null,
        montoEfectivo: _medioPago == 'MIXTO' ? _montoIngresado : null,
        usuarioId: widget.usuarioId,
        sesionId: widget.sesionId,
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
      title: const Text('Cobrar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total: ${_currency.format(_total)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _medioPagoLabels.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _medioPago == e.key,
                      onSelected: (_) => setState(() {
                        _medioPago = e.key;
                        _error = null;
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          if (_medioPago == 'EFECTIVO' || _medioPago == 'MIXTO') ...[
            TextField(
              controller: _montoController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _medioPago == 'EFECTIVO' ? 'Monto recibido' : 'Monto pagado en efectivo',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (_medioPago == 'EFECTIVO') Text('Cambio: ${_currency.format(_cambio < 0 ? 0 : _cambio)}'),
          ] else
            const Text('Confirma para registrar la venta.'),
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
