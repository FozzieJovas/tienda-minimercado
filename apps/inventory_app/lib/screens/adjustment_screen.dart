import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';
import 'barcode_scanner_screen.dart';

class AdjustmentScreen extends StatefulWidget {
  const AdjustmentScreen({super.key});

  @override
  State<AdjustmentScreen> createState() => _AdjustmentScreenState();
}

class _AdjustmentScreenState extends State<AdjustmentScreen> {
  final _api = ApiClient(SettingsService());

  Future<void> _escanear() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;

    try {
      final product = await _api.findByBarcode(code);
      if (!mounted) return;
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No existe ningún producto con ese código')));
        return;
      }

      final result = await showDialog<_AdjustmentInput>(
        context: context,
        builder: (context) => _AdjustmentDialog(productName: product.nombre, stockActual: product.stockActual),
      );
      if (result == null) return;

      await _api.ajustarStock(
        productId: product.id,
        cantidadDelta: result.cantidadDelta,
        tipo: result.tipo,
        motivo: result.motivo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock ajustado')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo conectar con el servidor')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajuste de inventario')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _escanear,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear producto'),
        ),
      ),
    );
  }
}

class _AdjustmentInput {
  final double cantidadDelta;
  final String tipo;
  final String? motivo;

  _AdjustmentInput(this.cantidadDelta, this.tipo, this.motivo);
}

class _AdjustmentDialog extends StatefulWidget {
  final String productName;
  final double stockActual;

  const _AdjustmentDialog({required this.productName, required this.stockActual});

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  final _cantidadController = TextEditingController();
  final _motivoController = TextEditingController();
  String _tipo = 'AJUSTE';
  bool _positivo = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.productName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Stock actual: ${widget.stockActual.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Sumar')),
              ButtonSegment(value: false, label: Text('Restar')),
            ],
            selected: {_positivo},
            onSelectionChanged: (s) => setState(() => _positivo = s.first),
          ),
          TextField(
            controller: _cantidadController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(value: 'AJUSTE', child: Text('Ajuste (conteo)')),
              DropdownMenuItem(value: 'MERMA', child: Text('Merma (pérdida/daño)')),
            ],
            onChanged: (v) => setState(() => _tipo = v ?? 'AJUSTE'),
          ),
          TextField(
            controller: _motivoController,
            decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            final cantidad = double.tryParse(_cantidadController.text);
            if (cantidad == null || cantidad <= 0) return;
            final delta = _positivo ? cantidad : -cantidad;
            Navigator.of(context).pop(
              _AdjustmentInput(delta, _tipo, _motivoController.text.trim().isEmpty ? null : _motivoController.text.trim()),
            );
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
