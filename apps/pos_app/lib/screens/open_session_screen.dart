import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_user.dart';
import '../models/cash_session.dart';
import '../services/api_client.dart';
import '../services/settings_service.dart';

class OpenSessionScreen extends StatefulWidget {
  final AppUser user;
  final void Function(CashSession session) onOpened;

  const OpenSessionScreen({super.key, required this.user, required this.onOpened});

  @override
  State<OpenSessionScreen> createState() => _OpenSessionScreenState();
}

class _OpenSessionScreenState extends State<OpenSessionScreen> {
  final _api = ApiClient(SettingsService());
  final _fondoController = TextEditingController(text: '0');
  bool _loading = false;
  String? _error;

  Future<void> _abrir() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fondo = double.tryParse(_fondoController.text) ?? 0;
      final session = await _api.openSession(fondoInicial: fondo, usuarioAperturaId: widget.user.id);
      widget.onOpened(session);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abrir turno de caja')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Hola, ${widget.user.nombre}'),
                const SizedBox(height: 16),
                TextField(
                  controller: _fondoController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Fondo inicial de caja'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _abrir,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Abrir turno'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
