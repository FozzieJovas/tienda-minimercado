import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../models/cash_session.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';

final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

class CashSessionScreen extends StatefulWidget {
  final AppUser user;
  final String sessionId;
  final VoidCallback onClosed;

  const CashSessionScreen({super.key, required this.user, required this.sessionId, required this.onClosed});

  @override
  State<CashSessionScreen> createState() => _CashSessionScreenState();
}

class _CashSessionScreenState extends State<CashSessionScreen> {
  final _api = ApiClient(SettingsService());
  CashSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _session = await _api.fetchCurrentSession();
    } catch (_) {
      // se mantiene el estado anterior si falla
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _agregarMovimiento(String tipo) async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) => _MontoDialog(titulo: tipo == 'INGRESO' ? 'Ingreso de efectivo' : 'Retiro de efectivo'),
    );
    if (result == null || result <= 0) return;
    try {
      await _api.addCashMovement(sessionId: widget.sessionId, tipo: tipo, monto: result);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo registrar el movimiento')));
      }
    }
  }

  Future<void> _cerrarTurno() async {
    final efectivoContado = await showDialog<double>(
      context: context,
      builder: (context) => const _MontoDialog(titulo: 'Efectivo contado en caja'),
    );
    if (efectivoContado == null) return;
    try {
      final closed = await _api.closeSession(
        sessionId: widget.sessionId,
        efectivoContado: efectivoContado,
        usuarioCierreId: widget.user.id,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turno cerrado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Efectivo esperado: ${_currency.format(closed.efectivoEsperado)}'),
              Text('Efectivo contado: ${_currency.format(closed.efectivoContado)}'),
              Text(
                'Diferencia: ${_currency.format(closed.diferencia)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: closed.diferencia == 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
      widget.onClosed();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo cerrar el turno')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turno de caja')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _session == null
              ? const Center(child: Text('No hay turno abierto'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Fondo inicial: ${_currency.format(_session!.fondoInicial)}'),
                    Text('Abierto: ${_session!.abiertoEn}'),
                    const Divider(height: 32),
                    const Text('Movimientos', style: TextStyle(fontWeight: FontWeight.bold)),
                    for (final m in _session!.movimientos)
                      ListTile(
                        title: Text(m.tipo),
                        subtitle: m.motivo != null ? Text(m.motivo!) : null,
                        trailing: Text(_currency.format(m.monto)),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _agregarMovimiento('INGRESO'),
                            child: const Text('Registrar ingreso'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _agregarMovimiento('RETIRO'),
                            child: const Text('Registrar retiro'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: _cerrarTurno, child: const Text('Cerrar turno')),
                  ],
                ),
    );
  }
}

class _MontoDialog extends StatefulWidget {
  final String titulo;

  const _MontoDialog({required this.titulo});

  @override
  State<_MontoDialog> createState() => _MontoDialogState();
}

class _MontoDialogState extends State<_MontoDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'Monto'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(double.tryParse(_controller.text)),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
