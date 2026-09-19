import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuantityCostResult {
  final double cantidad;
  final double costoUnitario;

  QuantityCostResult(this.cantidad, this.costoUnitario);
}

Future<QuantityCostResult?> showQuantityCostDialog(
  BuildContext context, {
  required String productName,
  double costoSugerido = 0,
}) {
  final cantidadController = TextEditingController(text: '1');
  final costoController = TextEditingController(
    text: costoSugerido > 0 ? costoSugerido.toStringAsFixed(0) : '',
  );

  return showDialog<QuantityCostResult>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(productName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: cantidadController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Cantidad recibida'),
          ),
          TextField(
            controller: costoController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Costo unitario de esta compra'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            final cantidad = double.tryParse(cantidadController.text);
            final costo = double.tryParse(costoController.text);
            if (cantidad == null || cantidad <= 0 || costo == null) return;
            Navigator.of(context).pop(QuantityCostResult(cantidad, costo));
          },
          child: const Text('Agregar'),
        ),
      ],
    ),
  );
}
