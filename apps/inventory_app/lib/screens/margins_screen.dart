import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';
import 'product_catalog_screen.dart';

const _margenDefaultKey = 'margen_default';

class MarginsScreen extends StatefulWidget {
  const MarginsScreen({super.key});

  @override
  State<MarginsScreen> createState() => _MarginsScreenState();
}

class _MarginsScreenState extends State<MarginsScreen> {
  final _api = ApiClient(SettingsService());
  final _margenController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _api.fetchSettings();
      final valor = double.tryParse(settings[_margenDefaultKey] ?? '') ?? 0.3;
      _margenController.text = (valor * 100).toStringAsFixed(0);
    } catch (_) {
      _error = 'No se pudo cargar la configuración';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guardar() async {
    final pct = double.tryParse(_margenController.text);
    if (pct == null) {
      setState(() => _error = 'Indica un margen válido en %');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.updateSetting(_margenDefaultKey, (pct / 100).toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Margen general guardado')));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo guardar');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Precios y márgenes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'El precio de venta se calcula automáticamente como '
                    'costo × (1 + margen), redondeado hacia arriba a la centena '
                    '(ej. \$2.475 → \$2.500).',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Text('Margen general de la tienda', style: Theme.of(context).textTheme.titleMedium),
                  const Text(
                    'Se aplica a todo producto que no tenga un margen propio configurado en el catálogo.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _margenController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Margen (%)', suffixText: '%'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _saving ? null : _guardar,
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Guardar'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Márgenes por producto', style: Theme.of(context).textTheme.titleMedium),
                  const Text(
                    'Cada producto puede tener su propio margen (anula el general). '
                    'También desde ahí se marca qué productos aparecen como favoritos en el POS.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProductCatalogScreen()),
                    ),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Ver catálogo de productos'),
                  ),
                ],
              ),
            ),
    );
  }
}
