import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';

final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _timeFormat = DateFormat('HH:mm');

class SalesTodayScreen extends StatefulWidget {
  const SalesTodayScreen({super.key});

  @override
  State<SalesTodayScreen> createState() => _SalesTodayScreenState();
}

class _SalesTodayScreenState extends State<SalesTodayScreen> {
  final _api = ApiClient(SettingsService());
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _api.fetchSalesToday();
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo cargar el reporte';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas de hoy'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final report = _report!;
    final ventas = report['ventas'] as List<dynamic>;
    final porMedioPago = report['porMedioPago'] as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Total del día: ${_currency.format(report['totalGeneral'])}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text('${report['cantidadVentas']} ventas'),
        const SizedBox(height: 16),
        const Text('Por medio de pago', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final entry in porMedioPago.entries)
          ListTile(
            title: Text(entry.key),
            trailing: Text(_currency.format(entry.value['total'])),
            subtitle: Text('${entry.value['cantidadVentas']} ventas'),
          ),
        const Divider(height: 32),
        const Text('Detalle', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final venta in ventas)
          ListTile(
            leading: Text('#${venta['numeroTicket']}'),
            title: Text(_timeFormat.format(DateTime.parse(venta['fecha']))),
            subtitle: Text(venta['medioPago']),
            trailing: Text(_currency.format(venta['total'])),
          ),
      ],
    );
  }
}
