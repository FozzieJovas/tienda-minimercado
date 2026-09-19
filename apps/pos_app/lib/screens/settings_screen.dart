import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../services/settings_service.dart';
import '../services/printer_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _printerService = PrinterService();
  final _urlController = TextEditingController();
  List<BluetoothInfo> _printers = [];
  String? _selectedMac;
  bool _loadingPrinters = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _urlController.text = await _settings.getServerUrl();
    _selectedMac = await _settings.getPrinterMac();
    if (mounted) setState(() {});
  }

  Future<void> _loadPrinters() async {
    setState(() => _loadingPrinters = true);
    try {
      _printers = await _printerService.pairedPrinters();
    } catch (_) {
      _printers = [];
    }
    if (mounted) setState(() => _loadingPrinters = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Servidor', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL del servidor',
              hintText: 'http://tienda.local:4000',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              await _settings.setServerUrl(_urlController.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('URL guardada')));
              }
            },
            child: const Text('Guardar URL'),
          ),
          const Divider(height: 32),
          const Text('Impresora Bluetooth', style: TextStyle(fontWeight: FontWeight.bold)),
          ElevatedButton(
            onPressed: _loadingPrinters ? null : _loadPrinters,
            child: Text(_loadingPrinters ? 'Buscando...' : 'Buscar impresoras emparejadas'),
          ),
          RadioGroup<String>(
            groupValue: _selectedMac,
            onChanged: (value) async {
              setState(() => _selectedMac = value);
              if (value != null) await _settings.setPrinterMac(value);
            },
            child: Column(
              children: [
                for (final printer in _printers)
                  RadioListTile<String>(
                    title: Text(printer.name),
                    subtitle: Text(printer.macAdress),
                    value: printer.macAdress,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
