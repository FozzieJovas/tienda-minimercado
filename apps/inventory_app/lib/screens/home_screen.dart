import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/session_service.dart';
import 'adjustment_screen.dart';
import 'reception_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppUser user;
  final VoidCallback onLoggedOut;

  const HomeScreen({super.key, required this.user, required this.onLoggedOut});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventario — ${user.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuración',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await SessionService().logout();
              onLoggedOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 260,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReceptionScreen(user: user)),
                ),
                icon: const Icon(Icons.inventory),
                label: const Text('Recepción de mercancía'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 260,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdjustmentScreen()),
                ),
                icon: const Icon(Icons.tune),
                label: const Text('Ajuste de inventario'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
